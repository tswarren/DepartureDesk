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
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "2027-03-11"
    fill_in "Required action or evidence", with: "Review retained cabins and release any unretained block by the option date"
    click_on "Save deadline"
    assert_text "Deadline saved"
    assert_text "Option or release date"

    click_on "Add Supplier deadline"
    select "Final payment", from: "Template"
    select "Actionable", from: "Kind"
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "2027-07-09"
    fill_in "Required action or evidence", with: "Record Supplier final-payment evidence"
    click_on "Save deadline"
    assert_text "Deadline saved"
    assert_text "Final payment"

    click_on "Add Supplier deadline"
    select "Rooming list", from: "Template"
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "2027-10-07"
    click_on "Save deadline"
    assert_text "Deadline saved"
    assert_text "Rooming list due"

    click_on "Add Supplier deadline"
    select "Other Supplier deadline", from: "Template"
    select "Informational", from: "Kind"
    fill_in "Label (for Final payment or Other)", with: "Broken sibling"
    select "Fixed date", from: "Timing rule"
    fill_in "Fixed date", with: "not-a-date"
    click_on "Save deadline"
    assert_text "ISO date"
    assert_field "Fixed date", with: "not-a-date"
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

  private

  def visit_deadlines_workspace
    visit departure_arrangement_cruise_path(@departure, @arrangement)
    click_on "Open deposits and deadlines"
    assert_selector "#cruise-deposits-and-deadlines"
  end
end
