# frozen_string_literal: true

require "application_system_test_case"

class HotelAgreementSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @departure.update!(time_zone: "America/New_York")
  end

  test "staff review a Hotel Agreement, record a deposit, and return from the stay editor" do
    sign_in_from_browser(@staff)
    visit new_departure_composition_suppliers_hotel_path(@departure)
    fill_in "Stay name", with: "Pre-cruise hotel stay"
    fill_in_html_date "Arrival date", "2027-11-04"
    fill_in_html_date "Departure date", "2027-11-06"
    find("#arrangement_contracting_supplier_id option[value='#{@contractor.id}']").select_option
    click_button "Save and continue"
    assert_selector "#room-categories-heading"

    click_link "Agreement"
    assert_selector "h2", text: "Hotel Agreement"
    assert_text "Arrival 2027-11-04"
    assert_text "Not confirmed"
    assert_text "Not reviewed"
    assert_no_text "Review & activate"
    assert_no_button "Activate"

    click_link "Add deposit"
    fill_in "Amount", with: "415.60"
    fill_in_html_date "Due date", "2026-10-01"
    click_button "Save deposit"
    assert_text "Deposit saved."
    assert_text "$415.60"
    assert_text "October 1, 2026"

    find("#hotel-step-stay").click
    fill_in_html_date "Departure date", "2027-11-07"
    click_button "Save stay"
    assert_text "Stay saved."
    assert_selector "h2", text: "Hotel Agreement"
    assert_text "Departure 2027-11-07"
  end

  test "staff record the four Hotel agreement terms without changing deposits or deadlines" do
    sign_in_from_browser(@staff)
    visit new_departure_composition_suppliers_hotel_path(@departure)
    fill_in "Stay name", with: "Pre-cruise hotel stay"
    fill_in_html_date "Arrival date", "2027-11-04"
    fill_in_html_date "Departure date", "2027-11-06"
    find("#arrangement_contracting_supplier_id option[value='#{@contractor.id}']").select_option
    click_button "Save and continue"
    assert_selector "#room-categories-heading"

    click_link "Agreement"
    terms = {
      "destination_fee" => "The $150 destination fee is waived.",
      "additional_nights" => "Additional nights November 1 through November 3 are available on request.",
      "early_departure" => "Early departure follows the Hotel's governing provision.",
      "cancellation" => "Cancellation follows the Hotel's governing provision."
    }
    terms.each do |kind, wording|
      within("#hotel-term-#{kind}") { click_link "Add wording" }
      choose "This Hotel stay"
      fill_in "Governing wording", with: wording
      fill_in "Supplier source", with: "Hilton agreement"
      click_button "Save term"
      assert_text "Agreement term saved."
      within("#hotel-term-#{kind}") { assert_text "Recorded" }
    end

    assert_text "The $150 destination fee is waived."
    assert_no_text "November 20, 2027"
    assert_no_button "Activate"
    within("#hotel-term-destination_fee") { click_link "Edit term" }
    fill_in "Supplier source", with: "Revised Hilton letter"
    click_button "Save term"
    within("#hotel-term-additional_nights") { click_link "Edit term" }
    assert_field "Supplier source", with: "Hilton agreement"
  end
end
