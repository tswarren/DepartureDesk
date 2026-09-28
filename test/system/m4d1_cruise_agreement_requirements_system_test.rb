# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseAgreementRequirementsSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
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
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: provider.id
      },
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
    [
      [ "E3", "Deluxe Oceanview" ],
      [ "O1", "Prime Oceanview" ],
      [ "DI", "Inside" ]
    ].each do |code, name|
      CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @staff,
        arrangement: @arrangement,
        resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
        pool_attributes: {
          inventory_mode: "block",
          proposed_opening_quantity: 8,
          evidence_kind: "contract",
          evidence_on: Date.current,
          evidence_reference_note: "Signed cabin block"
        },
        version_lock_version: @version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
  end

  test "staff reviews requirements in four sections and records the canonical deposit and deadlines" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_selector "h2", text: "Agreement"
    assert_selector "h2", text: "Deposits & deadlines"
    assert_selector "h2", text: "Commercial benefits"
    assert_selector "h2", text: "Other Supplier terms"
    within("section[aria-labelledby='agreement']") do
      assert_selector "h2", text: "Agreement"
      assert_no_selector "h2", text: "Deposits & deadlines"
    end
    within("section[aria-labelledby='deposits-and-deadlines']") do
      assert_no_selector "h2", text: "Commercial benefits"
    end
    headings = all("h2").map(&:text)
    assert_operator headings.index("Agreement"), :<, headings.index("Deposits & deadlines")
    assert_operator headings.index("Deposits & deadlines"), :<, headings.index("Commercial benefits")
    assert_operator headings.index("Commercial benefits"), :<, headings.index("Other Supplier terms")

    fill_in "Supplier group number", with: "1119999"
    fill_in_html_date "Contract date", "2026-09-13"
    fill_in_html_date "agreement_group_creation_date_confirm", "2026-09-13"
    click_on "Confirm Supplier agreement"
    assert_text "Cruise agreement recorded."
    assert_text "Group 1119999"
    within("section[aria-labelledby='agreement']") do
      assert_text "Confirmed"
    end
    assert_no_button "Correct confirmation"

    click_on "Correct"
    assert_field "Supplier group number", with: "1119999"
    click_on "Cancel"
    assert_text "Group 1119999"
    assert_no_field "Supplier group number"

    assert_text "Suggested due date: October 13, 2026"
    click_link "Add", href: /focus=deposit-new-initial/
    fill_in "Amount per opening cabin (USD)", with: "50.00"
    fill_in_html_date "Due date", "2026-10-20"
    click_on "Add Initial Deposit"
    assert_text "Deposit requirement saved."
    assert_text "$50.00 per opening cabin × 24 cabins = $1,200.00"
    assert_text "Due October 20, 2026"

    click_on "Edit", match: :first
    assert_field "Due date", with: "2026-10-20"
    fill_in_html_date "Due date", "2026-10-13"
    click_on "Save Initial Deposit"
    within("section[aria-labelledby='deposits-and-deadlines']") do
      assert_text "Due October 13, 2026"
      assert_text "$50.00 per opening cabin × 24 cabins = $1,200.00"
    end
    click_on "Edit", match: :first
    assert_field "Due date", with: "2026-10-13"
    click_on "Cancel"

    events_before = CapacityEvent.count
    click_link "Add", href: /focus=deadline-new-hard-stop/
    fill_in_html_date "Date", "2027-07-09"
    fill_in "Required action", with: "Name and fully deposit allocated staterooms, or release remaining inventory."
    within "#cruise-deadline-focus-deadline-new-hard-stop" do
      click_button "Add"
    end
    assert_text "Deadline saved."
    assert_text "July 9, 2027"
    assert_text "Name and fully deposit allocated staterooms, or release remaining inventory."
    assert_equal events_before, CapacityEvent.count

    click_link "Add", href: /focus=deadline-new-final-payment/
    fill_in_html_date "Date", "2027-08-08"
    within "#cruise-deadline-focus-deadline-new-final-payment" do
      click_button "Add"
    end
    assert_text "August 8, 2027"

    resize_window(1280, 900)
    assert_no_page_overflow
    resize_window(375, 900)
    assert_no_page_overflow
  end

  test "staff records allocated credit, a cancellation ladder, and formatted wording" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)

    click_link "Add", href: /focus=term-allocated/
    fill_in "Amount per allocated cabin (USD)", with: "500.00"
    fill_in "Attributable initial-deposit credit (USD)", with: "50.00"
    fill_in "Policy details", with: "Applies to allocated staterooms.\n\n**Not** current exposure."
    click_on "Add allocated cabin deposit"
    within("section[aria-labelledby='other-supplier-terms']") do
      assert_text "$500.00"
      assert_text "Amount per allocated cabin"
      assert_text "$50.00"
      assert_text "Attributable initial-deposit credit"
      assert_selector "strong", text: "Not"
      assert_no_text "$500.00 × 24"
    end

    click_on "Edit", exact: true
    assert_field "Attributable initial-deposit credit (USD)", with: "50.00"
    assert_field "Policy details", with: "Applies to allocated staterooms.\n\n**Not** current exposure."
    click_on "Cancel"

    click_link "Add step"
    fill_in "Days before departure", with: "120"
    fill_in "Policy wording", with: "Deposit becomes non-refundable."
    click_on "Save step"
    assert_text "120 days before departure"
    assert_text "Deposit becomes non-refundable."

    click_link "Add step"
    fill_in "Days before departure", with: "90"
    fill_in "Policy wording", with: "Additional penalties apply."
    click_on "Save step"
    assert_text "120 days before departure"
    assert_text "90 days before departure"
    within "ol" do
      assert_link "Edit"
      assert_button "Remove"
    end

    within "ol" do
      first(:link, "Edit").click
    end
    fill_in "Policy wording", with: "Deposit stays non-refundable."
    click_on "Save step"
    assert_text "Deposit stays non-refundable."
    assert_text "Additional penalties apply."

    accept_confirm do
      within("ol") { first(:button, "Remove").click }
    end
    assert_no_text "Deposit stays non-refundable."
    assert_text "Additional penalties apply."

    accept_confirm do
      click_on "Remove"
    end
    assert_text "Not recorded"
    assert_no_text "Additional penalties apply."

    within "#commercial-benefit-tour-conductor-credit" do
      click_link "Add"
    end
    fill_in "Wording", with: "1 credit per 16 guests.\n\n<script>alert(1)</script>"
    click_on "Add Tour-conductor credit"
    assert_text "1 credit per 16 guests."
    assert_no_selector ".dd-reference-text script"
    within "#commercial-benefit-tour-conductor-credit" do
      click_link "Edit"
    end
    assert_field "Wording", with: "1 credit per 16 guests.\n\n<script>alert(1)</script>"
  end

  test "activated cruises still show the transitional capacity controls" do
    RecordCruiseSupplierAgreement.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      intent: "confirm",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      group_reference: "1119999",
      contract_date: "2026-09-13",
      group_creation_date: "2026-09-13"
    ).call
    @departure.update!(
      status: "active",
      departure_reference: "D-111999",
      first_activated_at: Time.current
    )
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Guaranteed cabins",
      fixed_quantity: 24,
      quantity_basis: "resource_units",
      position: 1
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
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call

    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_selector "h2", text: "Later capacity"
    assert_button "Record same-terms increase"
    assert_button "Add supplemental O1 block"
    assert_selector "h2", text: "Agreement"
  end

  test "an unrecognized requirement links to advanced planning" do
    attributes = CruiseDeadlineTemplateSupport.compile_attributes(
      template_key: "rooming_list",
      kind: "informational",
      other_label: nil,
      description: nil,
      warning_lead_days: nil,
      timing: { rule_shape: "fixed_date", fixed_date: "2027-10-01" },
      coverage: { scope: "arrangement" },
      arrangement: @arrangement,
      version: @version.reload,
      cruise_item: @arrangement.arrangement_items.sole
    )
    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: attributes,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_text "Rooming list"
    click_link "Additional Supplier requirement — Review in Advanced"
    assert_current_path departure_arrangement_version_deadlines_path(
      @departure, @arrangement, @version, return_to: "cruise_deposits_and_deadlines"
    )
    assert_text "Rooming list"
  end
end
