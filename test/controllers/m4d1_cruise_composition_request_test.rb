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
    assert_select "a", text: "Add a cabin category"
    assert_no_match(/\bItem\b|\bOccurrence\b|\bResource\b|\bPool\b/, response.body)
  end

  test "add cabin category appears on cruise workspace" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole

    post departure_arrangement_cruise_cabin_categories_path(@departure, arrangement), params: {
      idempotency_key: SecureRandom.uuid,
      version_lock_version: version.lock_version,
      resource: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      commit: "Save category"
    }

    assert_redirected_to departure_arrangement_cruise_path(@departure, arrangement)
    follow_redirect!
    assert_response :success
    assert_match "O1", response.body
    assert_match "Prime Oceanview", response.body
    assert_match "sleeps up to 3", response.body
    assert_match "8 cabins", response.body
    assert_match "Fixed block", response.body
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
      prefix: "Hotel"
    )[:arrangement]

    get suppliers_departure_composition_path(@departure)
    assert_response :success
    assert_select "a", text: "Set up a Cruise"
    assert_select "a[href=?]", departure_arrangement_cruise_path(@departure, cruise), text: "Open Cruise setup"
    assert_select "a[href=?]", departure_arrangement_path(@departure, lodging), text: "Open advanced Arrangement"
    assert_select "a[href=?]", departure_arrangement_cruise_path(@departure, lodging), count: 0
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
    assert_select "a", text: "Edit"
    assert_match "O1", response.body
    assert_match "sleeps up to 3", response.body

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

    assert_redirected_to departure_arrangement_cruise_path(@departure, arrangement)
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

  private

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
