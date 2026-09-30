# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseWorkspaceClosureSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
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
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: provider.id },
      occurrence_attributes: {
        name: "Western Caribbean",
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
    record_supported_supplier_terms!
    @offer = connect_client_offer
  end

  test "staff moves through the cruise workspaces without a second editor or a client change" do
    sign_in_from_browser(@staff)
    before_activation = client_snapshot(@offer)

    visit departure_arrangement_cruise_path(@departure, @arrangement)
    assert_workspace_page("Celebrity Beyond", badge: "Draft")
    assert_text "Open Cabin inventory"
    assert_text "Open Supplier rates"
    assert_text "Open agreement"
    assert_no_text "Advanced structure"
    assert_no_text "Change inventory"
    assert_no_link "Add cabin categories"
    assert_no_selector "#cruise-setup-nav .dd-journey-step__status", text: "Advanced"
    assert_no_page_overflow_at_widths

    find("#cruise-step-sailing").click
    assert_workspace_page("Edit sailing", current: "sailing")
    assert_field "Ship"
    assert_field "Sailing or itinerary name"
    assert_no_field "Supplier group number"
    assert_no_field "Group creation date"
    assert_no_field "Contract date"
    assert_no_text "Advanced structure"

    find("#cruise-step-cabins").click
    assert_workspace_page("Cabin inventory", current: "cabins")
    assert_text "8 cabins"
    assert_no_selector "#cruise-supplier-rate-terms"
    assert_no_button "Activate Supplier terms"
    assert_no_page_overflow_at_widths

    find("#cruise-step-rates").click
    assert_workspace_page("Supplier rates", current: "rates")
    assert_no_text "Advanced structure"
    assert_no_page_overflow_at_widths

    find("#cruise-step-agreement").click
    assert_workspace_page("Agreement", current: "agreement")
    assert_text "Supplier group number"
    assert_text "1119999"
    assert_text "Group creation date"
    assert_text "Contract date"
    assert_no_link "Change inventory"
    assert_no_link "Open deposits and deadlines"
    assert_no_button "Activate Supplier terms"
    assert_no_page_overflow_at_widths

    find("#cruise-step-review").click
    assert_workspace_page("Review & activate", current: "review")
    assert_text "Ready to review"
    assert_no_text "Advanced structure"
    assert_no_text "Blocked"
    assert_no_page_overflow_at_widths
    select "Supplier confirmation", from: "Evidence kind"
    fill_in_html_date "Evidence date", with: Date.current.iso8601
    fill_in "Channel", with: "portal"
    fill_in "Reference note", with: "Supplier approved the terms"
    fill_in "Reason no Supplier identifier was issued", with: "Supplier did not issue one"
    click_on "Activate Supplier terms"
    assert_text "became governing"
    assert_equal before_activation, client_snapshot(@offer)

    visit departure_arrangement_cruise_active_version_path(@departure, @arrangement)
    assert_workspace_page("Active Supplier terms", badge: "Active")
    assert_text "These Supplier terms currently govern."
    assert_text "Current active capacity: 8 cabins"
    assert_text "Original opening quantity: 8 cabins"
    assert_link "Add cabins under same Supplier terms"
    assert_no_link "Propose changed terms"
    assert_no_page_overflow_at_widths

    before_increase = client_snapshot(@offer)
    click_on "Add cabins under same Supplier terms"
    assert_text "Active Version 1"
    assert_field "Cabin category"
    assert_field "Additional cabins"
    assert_text "Current Supplier capacity"
    assert_text "8 cabins"
    fill_in "Additional cabins", with: "4"
    fill_in "Deposit per additional cabin (USD)", with: "50.00"
    fill_in_html_date "Evidence date", with: Date.current.iso8601
    fill_in "Evidence note", with: "Supplier added four O1 cabins"
    click_on "Review this increase"
    click_on "Record capacity increase"
    assert_text "Current active capacity: 12 cabins"
    assert_text "Original opening quantity: 8 cabins"
    assert_equal 12, @pool.reload.capacity_projection.current_supplier_capacity
    assert_equal 8, @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).proposed_opening_quantity
    assert_equal before_increase, client_snapshot(@offer)

    before_successor = client_snapshot(@offer)
    click_on "Change inventory"
    assert_no_page_overflow_at_widths
    click_on "Propose changed terms"
    assert_text "Active Version 1 remains in effect."
    assert_field "Cabins proposed"
    fill_in "Maximum occupancy", with: "3"
    fill_in "Cabins proposed", with: "4"
    click_on "Propose changed terms"
    assert_text "Draft · Version 2"
    assert_text "Proposed changes to Active Version 1"
    assert_text "Carried from active terms"
    assert_text "Proposed · 4 cabins"
    assert_text "Current Supplier capacity: 12 cabins"
    assert_no_text "16 cabins"
    assert_equal before_successor, client_snapshot(@offer)

    click_on "View active version"
    assert_text "Active · Version 1"
    assert_text "These Supplier terms currently govern."
    assert_text "A proposed successor exists."
    assert_no_text "Supplemental O1 block"
    assert_no_text "Proposed · 4 cabins"
    assert_no_button "Activate Supplier terms"
  end

  private

  def record_supported_supplier_terms!
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      group_creation_date: "2026-09-01",
      contract_date: "2026-09-13"
    ).call
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
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
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      expected_cabins: { double: 1 },
      version_lock_version: @version.reload.lock_version
    ).call
    RecordCruiseContractedRates.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    definition = @version.reload.supplier_cost_definitions.find_by!(stage: "contracted")
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: definition.lock_version,
      readiness_provenance: "Signed terms",
      confirm_omissions: true,
      stage: "contracted"
    ).call
  end

  def connect_client_offer
    offer = ConnectCruiseServiceOffer.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        mode: "new",
        title: "Oceanview",
        supplier_arrangement_version_id: @version.id,
        use_tentative_draft: true,
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
    offer
  end

  def client_snapshot(offer)
    offer.reload
    version = offer.editable_draft_version
    {
      offer_id: offer.id,
      status: version.status,
      bindings: version.source_bindings.order(:id).pluck(:supplier_resource_id, :supplier_arrangement_version_id),
      price: version.price_definition.attributes.slice("id", "mode", "currency"),
      choices: version.choice_options.order(:position).map { |option|
        option.attributes.slice("id", "client_rate_category_key", "price_effect_minor_units")
      },
      sales_enabled: version.sales_state.sales_enabled
    }
  end

  def assert_workspace_page(title, current: nil, badge: nil)
    assert_selector "h1", count: 1, text: title
    assert_selector ".dd-cruise-version-badge", text: badge if badge
    assert_selector "#cruise-step-#{current}[aria-current='page']" if current
  end

  def assert_no_page_overflow_at_widths
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
    end
  end
end
