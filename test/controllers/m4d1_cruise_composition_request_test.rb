# frozen_string_literal: true

require "test_helper"

class M4d1CruiseCompositionRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @office = offices(:harbor_main)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
  end

  test "set up cruise create redirects to typed workspace" do
    sign_in_as @staff

    assert_difference -> { @departure.supplier_arrangements.count }, 1 do
      post departure_composition_suppliers_cruises_path(@departure), params: {
        idempotency_key: SecureRandom.uuid,
        arrangement: {
          name: "Celebrity group agreement",
          contracting_supplier_id: @contractor.id
        },
        item: { name: "Celebrity Beyond" },
        occurrence: {
          name: "Western Caribbean",
          starts_on: "2027-11-06",
          ends_on: "2027-11-13",
          time_zone: "America/New_York"
        },
        commit: "Save sailing and continue"
      }
    end

    arrangement = @departure.supplier_arrangements.find_by!(name: "Celebrity group agreement")
    assert_redirected_to departure_arrangement_cruise_path(@departure, arrangement)
    follow_redirect!
    assert_response :success
    assert_select "#cruise-workspace"
    assert_match "Celebrity Beyond", response.body
    assert_match "Western Caribbean", response.body
    assert_select "a", text: "Open Cabin inventory"
    assert_select "a", text: "Add cabin categories", count: 0
    assert_select "ol.dd-journey-strip .dd-journey-step", count: 5
    assert_no_match(/name="group_creation_date"/, response.body)
    assert_no_match("Commercial benefits", response.body)
    assert_no_match(/\bItem\b|\bOccurrence\b|\bResource\b|\bPool\b/, response.body)
  end

  test "add cabin category appears on cruise workspace" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole

    post departure_arrangement_cruise_cabin_categories_path(@departure, arrangement), params: {
      version_lock_version: version.lock_version,
      rows: [
        {
          idempotency_key: SecureRandom.uuid,
          name: "Prime Oceanview",
          supplier_code: "O1",
          maximum_occupancy: 3,
          inventory_mode: "block",
          proposed_opening_quantity: 8
        }
      ]
    }

    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    follow_redirect!
    assert_response :success
    assert_match "O1", response.body
    assert_match "Prime Oceanview", response.body
    assert_match "sleeps up to 3", response.body
    assert_match "8 cabins", response.body
    assert_match "Fixed block", response.body
    assert_equal 0, ServiceOffer.where(departure: @departure).count
  end

  test "a failed cabin row keeps earlier categories and retries without duplicating them" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    keys = Array.new(3) { SecureRandom.uuid }
    rows = [
      cabin_row("E3", "Edge Stateroom with Veranda", keys[0]),
      cabin_row("O1", "Prime Oceanview", keys[1]),
      cabin_row("DI", "Deluxe Inside Stateroom", keys[2])
    ]

    with_o1_command_failure do
      post departure_arrangement_cruise_cabin_categories_path(@departure, arrangement), params: {
        version_lock_version: version.lock_version,
        rows: rows
      }
    end

    assert_response :unprocessable_entity
    assert_match "O1 could not be saved", response.body
    assert_equal [ "O1", "DI" ], input_values("rows[][supplier_code]")
    assert_equal [ "Prime Oceanview", "Deluxe Inside Stateroom" ], input_values("rows[][name]")
    assert_equal [ "3", "3" ], input_values("rows[][maximum_occupancy]")
    assert_equal [ "8", "8" ], input_values("rows[][proposed_opening_quantity]")
    assert_equal [ keys[1], keys[2] ], input_values("rows[][idempotency_key]")
    assert_not_includes response.body, keys[0]
    assert_not_includes input_values("rows[][name]"), "Edge Stateroom with Veranda"
    assert_equal [ "E3" ], cabin_codes(arrangement)

    lock = css_select("input[name='version_lock_version']").first["value"]
    post departure_arrangement_cruise_cabin_categories_path(@departure, arrangement), params: {
      version_lock_version: lock,
      rows: [ rows[1], rows[2] ]
    }

    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_equal [ "E3", "O1", "DI" ], cabin_codes(arrangement)
    follow_redirect!
    assert_match "3 categories · 24 cabins", response.body
  end

  test "repeated supplier codes save when the cabin names differ" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole

    post departure_arrangement_cruise_cabin_categories_path(@departure, arrangement), params: {
      version_lock_version: version.lock_version,
      rows: [
        cabin_row("O1", "Prime Oceanview", SecureRandom.uuid),
        cabin_row("O1", "Supplemental O1 block", SecureRandom.uuid)
      ]
    }

    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_equal [ "O1", "O1" ], cabin_codes(arrangement)
    names = arrangement.versions.find_by!(status: "draft").supplier_resource_definitions.order(:position, :id).pluck(:name)
    assert_equal [ "Prime Oceanview", "Supplemental O1 block" ], names
    follow_redirect!
    assert_select "#cruise-cabin-table tbody tr", count: 2
    assert_match "Prime Oceanview", response.body
    assert_match "Supplemental O1 block", response.body
  end

  test "focused cabin page removes a category and returns to cabin inventory" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin_via_http_helper(arrangement, version)

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-cabins a", text: "Edit", count: 0
    assert_select "#cruise-cabins button", text: "Remove", count: 0
    assert_select "#cruise-cabins a", text: "Add cabin categories", count: 0
    assert_select "#cruise-cabins a", text: "Change inventory", count: 0

    get edit_departure_arrangement_cruise_cabin_category_path(@departure, arrangement, cabin.record.resource)
    assert_response :success
    assert_select "button", text: "Remove cabin category"
    assert_select "a", text: "Cabin inventory"

    delete departure_arrangement_cruise_cabin_category_path(@departure, arrangement, cabin.record.resource),
      params: { version_lock_version: version.reload.lock_version }

    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_empty arrangement.supplier_resources.reload
    follow_redirect!
    assert_match "Cabin category removed.", response.body
    assert_no_match "Prime Oceanview", response.body
  end

  test "cross-agency cruise routes return not found" do
    other = agencies(:cove)
    foreign_departure = create_capacity_departure(other, name: "Foreign Cruise")
    foreign_supplier = create_capacity_supplier(other, "Foreign Line")
    foreign = CreateCruiseSailingSetup.new(
      agency: other,
      actor: agency_users(:cove_admin),
      departure: foreign_departure,
      arrangement_attributes: {
        name: "Foreign agreement",
        contracting_supplier_id: foreign_supplier.id
      },
      item_attributes: { name: "Foreign Ship" },
      occurrence_attributes: {
        name: "Foreign sailing",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call.record.arrangement

    sign_in_as @staff
    get new_departure_composition_suppliers_cruise_path(foreign_departure)
    assert_response :not_found
    get departure_arrangement_cruise_path(foreign_departure, foreign)
    assert_response :not_found
    get departure_arrangement_cruise_path(@departure, foreign)
    assert_response :not_found
  end

  test "incompatible shape falls open to summary and advanced link" do
    sign_in_as @staff
    lodging = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @contractor,
      prefix: "Lodging"
    )
    arrangement = lodging[:arrangement]

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-incompatible"
    assert_select "a", text: "Open advanced Supplier planning"
    assert_match "advanced structure", response.body
    assert_select "#cruise-workspace", count: 0
  end

  test "open cruise setup appears for compatible arrangements on suppliers page" do
    sign_in_as @staff
    cruise = create_cruise_sailing.record.arrangement
    lodging = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @contractor,
      prefix: "Hotel",
      category: "lodging"
    )[:arrangement]

    get suppliers_departure_composition_path(@departure)
    assert_response :success
    assert_select "a", text: "Set up a Cruise"
    assert_select "a[href=?]", departure_arrangement_cruise_path(@departure, cruise), text: "Open Cruise setup"
    lodging_item = lodging.arrangement_items.order(:created_at).first
    assert_select "a[href=?]",
      item_hotel_agreement_departure_arrangement_hotel_path(@departure, lodging, lodging_item),
      text: "Open Hotel Agreement"
    assert_select "a[href=?]", departure_arrangement_path(@departure, lodging), count: 0
    assert_select "a[href=?]", departure_arrangement_cruise_path(@departure, lodging), count: 0
    assert_select "a[href=?]", departure_arrangement_hotel_path(@departure, cruise), count: 0
  end

  test "activated cruise successor lands on typed workspace with copied cabin facts" do
    sign_in_as @staff
    arrangement, version, resource_definition = activate_cruise_with_cabin!

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "form[action=?]", successor_departure_arrangement_cruise_path(@departure, arrangement)
    assert_select "button", text: "Create successor draft"

    assert_difference -> { arrangement.versions.count }, 1 do
      post successor_departure_arrangement_cruise_path(@departure, arrangement), params: {
        arrangement_lock_version: arrangement.reload.lock_version,
        version_lock_version: version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      }
    end

    assert_redirected_to departure_arrangement_cruise_path(@departure, arrangement)
    follow_redirect!
    assert_response :success
    assert_select "#cruise-workspace"
    assert_select "a", text: "Edit sailing"
    assert_select "a", text: "Open Cabin inventory"
    assert_match "carried from active terms", response.body

    get departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_response :success
    assert_match "O1", response.body
    assert_match "sleeps up to 3", response.body
    assert_match "Carried from active terms", response.body

    draft = arrangement.versions.find_by!(status: "draft")
    copied = draft.supplier_resource_definitions.find_by!(
      supplier_resource_id: resource_definition.supplier_resource_id
    )
    assert_equal "O1", copied.supplier_code
    assert_equal 3, copied.maximum_occupancy
    assert_predicate draft, :draft?
  end

  test "staff cabin update preserves administrator override" do
    sign_in_as @staff
    admin = agency_users(:harbor_admin)
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: admin,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        override: true,
        override_reason: "Administrator verified the exception."
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    resource = cabin.record.resource
    resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource: resource)
    pool_definition = version.capacity_pool_definitions.find_by!(capacity_pool: cabin.record.pool)
    assert_predicate pool_definition, :override?

    patch departure_arrangement_cruise_cabin_category_path(@departure, arrangement, resource), params: {
      version_lock_version: version.reload.lock_version,
      resource_lock_version: resource_definition.lock_version,
      pool_lock_version: pool_definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      resource: {
        name: "Prime Oceanview Updated",
        supplier_code: "O1",
        maximum_occupancy: 4
      },
      pool: {
        proposed_opening_quantity: 9,
        notes: "Staff note only",
        evidence_kind: "",
        evidence_on: "",
        evidence_reference_note: "",
        evidence_external_reference: ""
      }
    }

    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    pool_definition.reload
    resource_definition.reload
    assert_predicate pool_definition, :override?
    assert_equal "Administrator verified the exception.", pool_definition.override_reason
    assert_equal "Prime Oceanview Updated", resource_definition.name
    assert_equal 4, resource_definition.maximum_occupancy
    assert_equal 9, pool_definition.proposed_opening_quantity
  end

  test "staff edit form shows override summary instead of blank evidence fields" do
    sign_in_as @staff
    admin = agency_users(:harbor_admin)
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: admin,
      arrangement: arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        override: true,
        override_reason: "Administrator verified the exception."
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    get edit_departure_arrangement_cruise_cabin_category_path(
      @departure, arrangement, cabin.record.resource
    )
    assert_response :success
    assert_match "Administrator override in effect", response.body
    assert_select "select#pool_evidence_kind", count: 0
    assert_select "input#pool_evidence_on", count: 0
  end

  test "traveler_positions pool is incompatible on cruise workspace" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    item = arrangement.arrangement_items.sole
    occurrence = item.service_occurrences.sole
    resource = CreateSupplierResource.new(
      agency: @agency,
      actor: @staff,
      item: item,
      attributes: { name: "Traveler positions cabin", supplier_code: "TP1" },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    ConfigureCapacityPairWithPool.new(
      agency: @agency,
      actor: @staff,
      item: item,
      service_occurrence: occurrence,
      supplier_resource: resource,
      pool_attributes: {
        inventory_mode: "block",
        measurement_basis: "traveler_positions",
        unit_label: "cabins",
        proposed_opening_quantity: 8,
        label: "Traveler positions inventory"
      },
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-incompatible"
    assert_match "resource units", response.body
  end

  test "suppliers page cruise shape detection stays query bounded" do
    sign_in_as @staff
    3.times do |index|
      CreateCruiseSailingSetup.new(
        agency: @agency,
        actor: @staff,
        departure: @departure,
        arrangement_attributes: {
          name: "Cruise agreement #{index}",
          contracting_supplier_id: @contractor.id
        },
        item_attributes: { name: "Ship #{index}" },
        occurrence_attributes: {
          name: "Sailing #{index}",
          starts_on: "2027-11-06",
          ends_on: "2027-11-13",
          time_zone: "America/New_York"
        },
        idempotency_key: SecureRandom.uuid
      ).call
    end

    get suppliers_departure_composition_path(@departure)
    assert_response :success

    queries = []
    callback = ->(*, payload) do
      queries << payload[:sql] if payload[:name] != "SCHEMA" && payload[:sql].to_s.start_with?("SELECT")
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      get suppliers_departure_composition_path(@departure)
    end

    assert_operator queries.size, :<, 40, "expected bounded suppliers queries, got #{queries.size}"
  end

  test "shared navigation keeps viewer destinations on pages that role can open" do
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin_via_http_helper(arrangement, version)
    resource = cabin.record.resource
    sign_in_as agency_users(:harbor_viewer)

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_nav_labels(except: [ "Cabin inventory", "Supplier rates" ])
    assert_select "a#cruise-step-sailing[href=?]",
      departure_arrangement_cruise_path(@departure, arrangement, anchor: "cruise-sailing")
    assert_select "a#cruise-step-cabins", count: 0
    assert_select "a#cruise-step-rates", count: 0
    assert_select "a", text: "Open Cabin inventory", count: 0
    assert_select "a", text: "Open Supplier rates", count: 0
    assert_match "1 category · 8 cabins", response.body
    assert_match "1 cabin category · 1 not recorded", response.body
    assert_select "a#cruise-step-agreement[href=?]",
      departure_arrangement_cruise_agreement_path(@departure, arrangement)
    assert_select "a#cruise-step-review[href=?]",
      departure_arrangement_cruise_activation_path(@departure, arrangement)
    assert_select "a[href=?]",
      edit_departure_arrangement_cruise_sailing_path(@departure, arrangement), count: 0
    assert_select "a[href=?]",
      edit_departure_arrangement_cruise_cabin_category_path(@departure, arrangement, resource), count: 0
    assert_select "a[href=?]",
      departure_arrangement_cruise_cabin_category_supplier_rates_path(@departure, arrangement, resource), count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "a", text: "Add Supplier rates", count: 0
    assert_select "a", text: "Add cabin categories", count: 0
    assert_select "#cruise-review-activate"
    assert_select "button", text: "Create successor draft", count: 0

    get departure_arrangement_cruise_agreement_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-setup-nav"
    get departure_arrangement_cruise_activation_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-setup-nav"
    get edit_departure_arrangement_cruise_sailing_path(@departure, arrangement)
    assert_response :redirect
    get departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_response :redirect
    get departure_arrangement_cruise_cabin_category_supplier_rates_path(@departure, arrangement, resource)
    assert_response :redirect
    get departure_arrangement_cruise_supplier_rates_path(@departure, arrangement)
    assert_response :redirect
  end

  test "staff overview links editors and keeps cabin and rate navigation on the summary cards" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin_via_http_helper(arrangement, version)
    resource = cabin.record.resource

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_nav_labels
    assert_select ".dd-cruise-version-badge", text: "Draft"
    assert_select ".dd-cruise-version-badge", text: /Version/, count: 0
    assert_select "a#cruise-step-sailing[href=?]",
      edit_departure_arrangement_cruise_sailing_path(@departure, arrangement)
    assert_select "a#cruise-step-cabins[href=?]",
      departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_select "a#cruise-step-rates[href=?]",
      departure_arrangement_cruise_supplier_rates_path(@departure, arrangement)
    assert_select "#cruise-step-agreement .dd-journey-step__status", text: "Not started"
    assert_select "#cruise-attention", text: /Confirm the Cruise supplier agreement/, count: 0
    assert_select "#cruise-review-activate[href=?]",
      departure_arrangement_cruise_activation_path(@departure, arrangement)
    assert_select "#cruise-cabins a", text: "Open Cabin inventory"
    assert_select "#cruise-cabins a", text: "Edit", count: 0
    assert_select "#cruise-cabins a", text: "Add cabin categories", count: 0
    assert_select "#cruise-cabins a", text: "Change inventory", count: 0
    assert_select "#cruise-rates a", text: "Open Supplier rates"
    assert_select "#cruise-rates a", text: "Add Supplier rates", count: 0
    assert_select "#cruise-rates a", text: "Review Supplier rates", count: 0
    assert_select "#cruise-client"
    assert_select "#cruise-recommended-next", count: 0
    assert_select "#cruise-maintenance", count: 0
    assert_select "#cruise-activation", count: 0
    assert_select "#cruise-requirements", count: 0
    assert_select "summary", text: "More actions"
    assert_select "button", text: "Create successor draft", count: 0

    get edit_departure_arrangement_cruise_sailing_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-setup-nav"
    assert_select "#cruise-step-sailing[aria-current=page]"
    assert_select "form[action=?]", departure_arrangement_cruise_sailing_path(@departure, arrangement)
    assert_select "a", text: "Back to Cruise"

    get new_departure_arrangement_cruise_cabin_category_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-step-cabins[aria-current=page]"
    assert_select "form[action=?]", departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)

    get departure_arrangement_cruise_cabin_category_supplier_rates_path(@departure, arrangement, resource)
    assert_response :success
    assert_select "#cruise-step-rates[aria-current=page]"
    assert_select "form[action=?]",
      departure_arrangement_cruise_cabin_category_supplier_rates_path(@departure, arrangement, resource)

    get departure_arrangement_cruise_agreement_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-step-agreement[aria-current=page]"
    assert_select "a", text: "Open deposits and deadlines", count: 0
    assert_select "h2", text: "Deposits"
    assert_select "h2", text: "Policies"

    get departure_arrangement_cruise_activation_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-step-review[aria-current=page]"
    assert_select "a[href=?]", departure_arrangement_cruise_agreement_path(@departure, arrangement)
  end

  test "version headings distinguish a draft, the active terms, and a successor" do
    sign_in_as @staff
    arrangement, version, = activate_cruise_with_cabin!

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select ".dd-cruise-version-badge", text: "Active"
    assert_select "#cruise-step-review .dd-journey-step__status", text: "Active"
    assert_select "button", text: "Create successor draft"

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-setup-nav"
    assert_select "form[action=?]", same_terms_departure_arrangement_cruise_inventory_change_path(@departure, arrangement)

    get changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, arrangement)
    assert_response :success
    assert_select "form[action=?]", changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, arrangement)

    post successor_departure_arrangement_cruise_path(@departure, arrangement), params: {
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    }
    follow_redirect!
    assert_select ".dd-cruise-version-badge", text: "Draft · Version 2"
    assert_match "Proposed changes to Active Version 1", response.body
    assert_select "a", text: "View active version"
    assert_select "#cruise-step-review .dd-journey-step__status", text: "Active", count: 0
    assert_select "button", text: "Create successor draft", count: 0

    get departure_arrangement_cruise_active_version_path(@departure, arrangement)
    assert_response :success
    assert_select ".dd-cruise-version-badge", text: "Active"
    assert_select "#cruise-setup-nav"
    assert_select "a", text: "Add cabins under same Supplier terms"
  end

  test "attention lists an unconfirmed agreement and incomplete opening together" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      intent: "save_provisional",
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_creation_date: "2026-09-13"
    ).call

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-attention", text: /Confirm the Cruise supplier agreement/
    assert_select "#cruise-attention", text: /opening cabin quantity|opening evidence/
    assert_select "#cruise-step-agreement .dd-journey-step__status", text: "Needs attention"
  end

  test "a ready estimate stays off the attention list while activation stays reachable" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin_via_http_helper(arrangement, version)
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource: cabin.record.resource,
      terms: {
        first_second_fare: "1624.00",
        additional_fare: "406.00",
        single_supplement: "1624.00",
        nccf: "320.00",
        first_second_discount: "150.00",
        additional_discount: "37.50",
        taxes_fees: "137.00"
      },
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-step-rates .dd-journey-step__status", text: "Needs attention"
    assert_select "#cruise-attention", text: /needs ready contracted Supplier rates/, count: 0
    assert_select "#cruise-step-agreement .dd-journey-step__status", text: "Not started"
    assert_select "#cruise-review-activate[href=?]",
      departure_arrangement_cruise_activation_path(@departure, arrangement)
  end

  test "cabin inventory landing shows attention, nonnumeric quantity, active capacity, and a successor split" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement

    get departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-step-cabins .dd-journey-step__status", text: "Not started"
    assert_match "No cabin categories yet.", response.body
    assert_select "a", text: "Add cabin categories"
    assert_select "a", text: "Change inventory", count: 0

    version = arrangement.versions.sole
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: { name: "Concierge", supplier_code: "C1", maximum_occupancy: 2 },
      pool_attributes: { inventory_mode: "on_request" },
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    get departure_arrangement_cruise_cabin_categories_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-step-cabins .dd-journey-step__status", text: "Needs attention"
    oceanview = arrangement.versions.sole.supplier_resource_definitions.find_by!(supplier_code: "O1")
    assert_select "#cruise-cabin-attention a[href=?]",
      edit_departure_arrangement_cruise_cabin_category_path(
        @departure, arrangement, oceanview.supplier_resource_id
      )
    assert_match "2 categories · 8 tracked cabins · 1 quantity not tracked", response.body
    assert_select "#cruise-cabin-table th", text: "Opening authority"
    assert_match "Quantity not tracked", response.body
    assert_select "a", text: /Not entered|Estimated|Contracted/

    active_arrangement, active_version, = activate_cruise_with_cabin!
    get departure_arrangement_cruise_cabin_categories_path(@departure, active_arrangement)
    assert_response :success
    assert_match "Current active capacity: 8 cabins", response.body
    assert_match "Original opening quantity: 8 cabins", response.body
    assert_select "a", text: "Prime Oceanview", count: 0
    assert_select "a", text: "Change inventory"
    assert_select "a[href=?]",
      same_terms_departure_arrangement_cruise_inventory_change_path(@departure, active_arrangement), count: 0

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, active_arrangement)
    assert_match "Active Version #{active_version.version_number}", response.body

    resource = active_arrangement.supplier_resources.sole
    assert_no_difference "ServiceOffer.count" do
      CreateCruiseSupplementalBlock.new(
        agency: @agency,
        actor: @staff,
        arrangement: active_arrangement,
        arrangement_lock_version: active_arrangement.reload.lock_version,
        version_lock_version: active_arrangement.governing_version.lock_version,
        idempotency_key: SecureRandom.uuid,
        maximum_occupancy: 3,
        opening_quantity: 4,
        supplier_resource_id: resource.id
      ).call
    end

    get departure_arrangement_cruise_cabin_categories_path(@departure, active_arrangement)
    assert_response :success
    assert_match "Carried from active terms", response.body
    assert_match "Proposed · 4 cabins", response.body
    assert_match "Supplemental O1 block", response.body
    assert_no_match(/1[0-9] cabins/, response.body)

    get departure_arrangement_cruise_active_version_path(@departure, active_arrangement)
    assert_select "a", text: "Add cabins under same Supplier terms", count: 1
    assert_select "a", text: "Yes — terms changed", count: 0
    assert_select "a", text: "Changed terms", count: 0
  end

  private

  def assert_nav_labels(except: [])
    [ "Sailing", "Cabin inventory", "Supplier rates", "Agreement", "Review & activate" ].each do |label|
      if except.include?(label)
        assert_select "#cruise-setup-nav .dd-journey-step__title", text: label, count: 0
      else
        assert_select "#cruise-setup-nav .dd-journey-step__title", text: label
      end
    end
  end

  def cabin_row(code, name, key)
    {
      idempotency_key: key,
      supplier_code: code,
      name: name,
      maximum_occupancy: 3,
      inventory_mode: "block",
      proposed_opening_quantity: 8
    }
  end

  def input_values(name)
    css_select("tbody input[name='#{name}']").filter_map { |input| input["value"].presence }
  end

  def cabin_codes(arrangement)
    arrangement.reload.versions.find_by!(status: "draft")
      .supplier_resource_definitions.order(:position, :id).pluck(:supplier_code)
  end

  def with_o1_command_failure
    original = CreateCruiseCabinCategorySetup.method(:new)
    failed = false
    CreateCruiseCabinCategorySetup.define_singleton_method(:new) do |**kwargs|
      command = original.call(**kwargs)
      code = kwargs[:resource_attributes].to_h.with_indifferent_access[:supplier_code]
      if code == "O1" && !failed
        failed = true
        command.define_singleton_method(:call) do
          raise AgencyCommand::Error.new("Supplier rejected this category.", code: :invalid)
        end
      end
      command
    end
    yield
  ensure
    CreateCruiseCabinCategorySetup.define_singleton_method(:new, original)
  end

  def create_cruise_sailing
    CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: { name: "Celebrity Beyond" },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def create_cabin_via_http_helper(arrangement, version)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def activate_cruise_with_cabin!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    sailing = create_cruise_sailing.record
    arrangement = sailing.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin_via_http_helper(arrangement, version)
    resource_definition = version.supplier_resource_definitions.find_by!(
      supplier_resource: cabin.record.resource
    )

    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      arrangement_item: sailing.item,
      charging_supplier: @contractor,
      label: "Entered cruise cost",
      position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      supplier_cost_source: source,
      stage: "contracted",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Included in package",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:cruise-activate",
      readiness_provenance: "Signed terms"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Eight guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )

    satisfy_cruise_activation_gate!(agency: @agency, actor: @staff, arrangement: arrangement, version: version)
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      version: version,
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call

    [ arrangement.reload, version.reload, resource_definition ]
  end
end
