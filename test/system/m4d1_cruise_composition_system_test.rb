# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseCompositionSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
  end

  test "staff records cruise sailing and cabin inventory without graph jargon" do
    sign_in_from_browser(@staff)

    visit departure_composition_path(@departure)
    within "nav[aria-label='Composition areas']" do
      click_link "Suppliers"
    end

    assert_selector "a", text: "Set up a Cruise"
    click_link "Set up a Cruise"

    assert_selector "h1.dd-page-title", exact_text: "Set up a Cruise"
    select supplier_option_text(@contractor), from: "Contracting Supplier"
    fill_in "Arrangement name", with: "Celebrity group agreement"
    fill_in "Ship", with: "Celebrity Beyond"
    fill_in "Sailing or itinerary name", with: "Western Caribbean"
    fill_in_html_date "Start date", "2027-11-06"
    fill_in_html_date "End date", "2027-11-13"
    select "America/New_York", from: "Time zone"
    click_button "Save sailing and continue"

    assert_selector "#cruise-workspace"
    assert_text "Celebrity Beyond"
    assert_text "Western Caribbean"
    assert_no_text "Arrangement Item"
    assert_no_text "Service Occurrence"
    assert_no_text "Supplier Resource"
    assert_no_text "Capacity Pool"

    click_link "Add a cabin category"
    fill_in "Supplier category code", with: "O1"
    fill_in "Category name", with: "Prime Oceanview"
    fill_in "Maximum occupancy", with: "3"
    select "Fixed block / held cabins", from: "Inventory treatment"
    fill_in "Cabin quantity", with: "8"
    click_button "Save category"

    assert_selector "#cruise-workspace"
    assert_text "O1"
    assert_text "Prime Oceanview"
    assert_text "sleeps up to 3"
    assert_text "8 cabins"
    assert_text "Fixed block"

    click_link "Back to Suppliers"
    assert_selector "a", text: "Open Cruise setup"

    arrangement = @departure.supplier_arrangements.find_by!(name: "Celebrity group agreement")
    visit departure_arrangement_path(@departure, arrangement)
    assert_text "Celebrity Beyond"
    assert_text "Prime Oceanview"
  end

  private

  def supplier_option_text(supplier)
    "#{supplier.display_name_for_directory} · #{supplier.supplier_reference}"
  end
end
