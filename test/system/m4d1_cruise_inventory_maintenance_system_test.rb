# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseInventoryMaintenanceSystemTest < ApplicationSystemTestCase
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    @item = sailing.record.item
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @pool = cabin.record.pool
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool: @pool)
    @deposit = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 5_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-10-13" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ {
          capacity_pool_id: @pool.id,
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: definition.service_occurrence_id,
          supplier_resource_id: definition.supplier_resource_id
        } ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
  end

  test "same-terms increase keeps the opening quantity and initial deposit" do
    resize_window(1280, 900)
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    click_on "No — same terms"
    fill_in "Additional cabins", with: "4"
    fill_in "Deposit per additional cabin (USD)", with: "50.00"
    fill_in_html_date "Evidence date", with: Date.current.iso8601
    fill_in "Evidence note", with: "Supplier added four O1 cabins"
    click_on "Review this increase"
    assert_text "$50.00 × 4 = $200.00"
    assert_text "The original Initial Deposit will not change."
    click_on "Record capacity increase"

    assert_text "Current active capacity is 12 cabins."
    assert_text "Increase deposit $200.00."
    assert_text "Original opening quantity remains 8."
    click_link "Open Cabin inventory"
    assert_text "Current active capacity: 12 cabins"
    assert_text "Original opening quantity: 8 cabins"
    assert_equal 8, @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).proposed_opening_quantity
    assert_equal [ @deposit.id, @deposit.lock_version, 5_000 ], deposit_identity
    assert_equal 12, @pool.reload.capacity_projection.current_supplier_capacity

    resize_window(375, 800)
    visit departure_arrangement_cruise_path(@departure, @arrangement)
    assert_no_page_overflow
    visit same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    assert_no_page_overflow
  end

  test "changed terms opens the draft snapshot and leaves the client service unchanged" do
    offer = ConnectCruiseServiceOffer.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new",
        title: "Oceanview",
        supplier_arrangement_version_id: @version.id,
        use_tentative_draft: false,
        arrangement_lock_version: @version.reload.lock_version,
        arrangement_item_id: @item.id,
        supplier_resource_ids: [ @resource.id ]
      }
    ).call.record
    draft = offer.editable_draft_version
    draft.create_price_definition!(
      agency: @agency, departure: @departure, service_offer: offer, currency: "USD",
      mode: "zero_price", zero_price_reason: "Included for now"
    )
    draft.create_sales_state!(agency: @agency, departure: @departure, sales_enabled: true)
    before = client_snapshot(offer)

    resize_window(1280, 900)
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    click_on "Yes — terms changed"
    fill_in "Maximum occupancy", with: "3"
    fill_in "Opening quantity", with: "4"
    click_on "Add supplemental block"

    assert_text "Draft · Version 2"
    assert_text "Proposed changes to Active Version 1"
    assert_text "opening evidence is incomplete."
    assert_selector "#cruise-step-agreement .dd-journey-step__status", text: "Not started"
    assert_no_text "Confirm the Cruise supplier agreement before activation."
    assert_text "needs ready contracted Supplier rates."
    assert_text "Record the deposit treatment for this supplemental block before activation."
    assert_text "Supplier inventory has changed. Client offering has not been changed automatically."
    click_on "View active version"
    assert_selector ".dd-cruise-version-badge", text: "Active"
    assert_no_text "These Supplier terms are in effect."
    assert_text "Draft Version 2 is in progress."
    assert_no_link "Review activation"
    assert_no_link "Open deposits and deadlines"
    click_on "Back to Draft Version 2"
    assert_text "Draft · Version 2"
    assert_equal before, client_snapshot(offer.reload)

    resize_window(375, 800)
    visit departure_arrangement_cruise_path(@departure, @arrangement)
    assert_no_page_overflow
    visit departure_arrangement_cruise_active_version_path(@departure, @arrangement)
    assert_no_page_overflow
  end

  private

  def deposit_identity
    record = @version.supplier_deposit_requirement_definitions.find(@deposit.id)
    [ record.id, record.lock_version, record.rate_minor_units ]
  end

  def client_snapshot(offer)
    version = offer.editable_draft_version
    {
      bindings: version.source_bindings.order(:id).pluck(:supplier_resource_id, :supplier_arrangement_version_id),
      price: version.price_definition.attributes.slice("id", "mode", "currency"),
      choices: version.choice_options.order(:position).map { |option|
        option.attributes.slice("id", "client_rate_category_key", "price_effect_minor_units")
      },
      sales_enabled: version.sales_state.sales_enabled
    }
  end
end
