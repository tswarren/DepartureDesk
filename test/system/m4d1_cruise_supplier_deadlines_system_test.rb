# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseSupplierDeadlinesSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

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
    version = @arrangement.versions.sole
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  test "staff adds option final payment and rooming list independently with recovery" do
    sign_in_from_browser(@staff)
    visit_deadlines_workspace

    click_on "Add Supplier deadline"
    select "Option/release decision", from: "Template"
    assert_no_selector :field, "Kind", visible: true
    assert_no_selector :field, "Label", visible: true
    select "Fixed date", from: "Timing rule"
    assert_selector :field, "Fixed date", visible: true
    assert_no_selector :field, "Day offset from Departure", visible: true
    fill_in "Fixed date", with: "2027-03-11"
    fill_in "Required action or evidence", with: "Review retained cabins and release any unretained block by the option date"
    assert_text "Due on 2027-03-11"
    assert_text "opens one actionable Supplier commitment"
    click_on "Save deadline"
    assert_text "Deadline saved"
    assert_text "Option or release date"
    assert_match(/#cruise-deadline-/, page.current_url)

    click_on "Add Supplier deadline"
    select "Final payment", from: "Template"
    assert_text "canonical template label"
    assert_selector :field, "Kind", visible: true
    select "Actionable", from: "Kind"
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "2027-07-09"
    fill_in "Required action or evidence", with: "Record Supplier final-payment evidence"
    click_on "Save deadline"
    assert_text "Deadline saved"
    assert_text "Final payment"

    click_on "Add Supplier deadline"
    select "Rooming list", from: "Template"
    assert_no_selector :field, "Kind", visible: true
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "2027-10-07"
    click_on "Save deadline"
    assert_text "Deadline saved"
    assert_text "Rooming list due"

    click_on "Add Supplier deadline"
    select "Other Supplier deadline", from: "Template"
    assert_selector :field, "Label", visible: true
    select "Informational", from: "Kind"
    fill_in "Label", with: "Broken sibling"
    select "Days before departure", from: "Timing rule"
    assert_selector :field, "Day offset from Departure", visible: true
    assert_no_selector :field, "Fixed date", visible: true
    fill_in "Day offset from Departure", with: "0"
    click_on "Save deadline"
    assert_text "valid day offset"
    assert_field "Day offset from Departure", with: "0"
    assert_selector "#form-error-summary[data-controller='form-error-summary']"
    assert_equal "form-error-summary", page.evaluate_script("document.activeElement && document.activeElement.id")
    assert_text "Option or release date"
    assert_text "Final payment"
    assert_text "Rooming list due"
  end

  test "staff removes a draft deadline with confirmation naming the definition" do
    sign_in_from_browser(@staff)
    visit_deadlines_workspace

    click_on "Add Supplier deadline"
    select "Rooming list", from: "Template"
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "2027-10-07"
    click_on "Save deadline"
    assert_text "Deadline saved"

    accept_confirm(/Remove Rooming list due/i) do
      click_on "Remove"
    end
    assert_text "Deadline removed"
    assert_no_text "Rooming list due"
  end

  test "editor reveals only applicable controls for coverage and composite timing" do
    sign_in_from_browser(@staff)
    visit_deadlines_workspace
    click_on "Add Supplier deadline"

    select "Other Supplier deadline", from: "Template"
    fill_in "Label", with: "Names packet"
    select "Earlier of", from: "Timing rule"
    assert_text "Composite arm 1"
    assert_text "Composite arm 2"
    select "Fixed date", from: "Arm rule", match: :first
    within first("fieldset", text: "Composite arm 1") do
      assert_selector :field, "Arm fixed date", visible: true
      fill_in "Arm fixed date", with: "2027-03-11"
    end
    within find("fieldset", text: "Composite arm 2") do
      select "Days before departure", from: "Arm rule"
      fill_in "Arm day offset", with: "30"
    end
    assert_text(/Earlier of/i)

    select "One cabin category", from: "What does it cover?"
    assert_selector :field, "Cabin category", visible: true
    assert_no_selector :field, "Capacity Pool", visible: true
    select "O1", from: "Cabin category"
    assert_text "Cabin category O1"
  end

  private

  def visit_deadlines_workspace
    visit departure_arrangement_cruise_path(@departure, @arrangement)
    click_on "Open deposits and deadlines"
    assert_selector "#cruise-deposits-and-deadlines"
  end
end
