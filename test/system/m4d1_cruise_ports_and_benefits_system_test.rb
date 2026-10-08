# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruisePortsAndBenefitsSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
  end

  test "staff records blank ports then named ports notes and commercial benefits" do
    sign_in_from_browser(@staff)
    visit departure_composition_path(@departure)
    within "nav[aria-label='Composition areas']" do
      click_link "Suppliers"
    end
    click_link "Set up a Cruise"

    select supplier_option_text(@contractor), from: "Contracting Supplier"
    fill_in "Arrangement name", with: "Celebrity group agreement"
    fill_in "Ship", with: "Celebrity Beyond"
    fill_in "Sailing or itinerary name", with: "Western Caribbean"
    fill_in_html_date "Start date", "2027-11-06"
    fill_in_html_date "End date", "2027-11-13"
    select "America/New_York", from: "Time zone"
    click_button_and_expect "Save sailing and continue", text: "Celebrity Beyond"

    assert_no_text "Departs"
    assert_no_text "Returns"
    assert_no_text "Itinerary notes:"
    assert_no_text "Commercial benefits"

    click_link "Edit sailing"
    fill_in "Departure port", with: "Barcelona"
    fill_in "Return port", with: "Civitavecchia"
    fill_in "Itinerary notes", with: "Sea day after leaving port"
    click_button_and_expect "Save sailing", text: "Sailing updated."

    assert_text "Barcelona"
    assert_text "Civitavecchia"
    assert_text "Sea day after leaving port"

    click_link "Open agreement"
    assert_selector "h2", text: "Benefits"
    assert_text "Normal commission stays in Supplier rates."
    assert_text "Agreement benefits are recorded for reference. DepartureDesk does not calculate earned entitlements."

    within "#commercial-benefit-tour-conductor-credit" do
      click_link "Add"
    end
    fill_in "Wording", with: "1 cruise-only credit per 16 qualifying full-tariff guests."
    click_button "Add Tour-conductor credit"
    assert_text "Commercial benefit saved."
    assert_text "Draft wording for this version. The group agreement is not Supplier-confirmed."

    within "#commercial-benefit-group-amenity-program" do
      click_link "Add"
    end
    fill_in "Wording", with: "Four group points, not five per traveler."
    click_button "Add Group Amenity Program"
    assert_text "Commercial benefit saved."
    assert_text "Four group points, not five per traveler."
    assert_text "Agreement benefits are recorded for reference. DepartureDesk does not calculate earned entitlements."
  end

  private

  def supplier_option_text(supplier)
    "#{supplier.display_name_for_directory} · #{supplier.supplier_reference}"
  end
end
