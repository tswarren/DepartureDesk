# frozen_string_literal: true

require "application_system_test_case"

class HotelLifecycleSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Reunion")
    @departure.update!(time_zone: "America/New_York")
  end

  test "staff activate the Hilton agreement and a successor without changing the governing facts" do
    sign_in_from_browser(@staff)
    visit new_departure_composition_suppliers_hotel_path(@departure)
    fill_in "Stay name", with: "Pre-cruise hotel stay"
    fill_in_html_date "Arrival date", "2027-11-04"
    fill_in_html_date "Departure date", "2027-11-06"
    find("#arrangement_contracting_supplier_id option[value='#{@contractor.id}']").select_option
    click_button "Save and continue"
    assert_selector "#room-categories-heading"
    assert_link "Return to Departure Composition"
    assert_no_text "Create Client Service"
    assert_no_text "Connect Client Service"

    fill_in "Room category", with: "Standard"
    click_button "Add room category"
    assert_text "Standard"
    fill_in "Room category", with: "Deluxe"
    click_button "Add room category"
    assert_text "Deluxe"

    fill_in "Contracted rooms for Standard on Nov 4", with: "5"
    fill_in "Contracted rooms for Deluxe on Nov 4", with: "2"
    fill_in "Contracted rooms for Standard on Nov 5", with: "10"
    fill_in "Contracted rooms for Deluxe on Nov 5", with: "5"
    select "Contract", from: "Evidence"
    fill_in_html_date "Evidence date", "2026-09-30"
    fill_in "Reference note", with: "Hilton group contract"
    click_button "Save room inventory"
    assert_text "Room inventory saved."

    find("#hotel-step-rates").click
    fill_in "Standard room night base", with: "173"
    fill_in "Deluxe room night base", with: "223"
    fill_in "Third occupant", with: "20"
    fill_in "Fourth occupant", with: "20"
    check "Net and noncommissionable"
    click_button "Save Supplier rates"
    assert_text "Supplier rates saved."
    assert_text "Nov 4 base block: $1,311.00"
    assert_text "Nov 5 base block: $2,845.00"
    assert_text "Current pretax contracted-room total: $4,156.00"

    find("#hotel-step-agreement").click
    assert_selector "h2", text: "Hotel Agreement"
    record_deposit("415.60", "2026-10-01")
    record_deposit("1870.20", "2027-05-07")
    record_deposit("1870.20", "2027-10-04")
    assert_text "$415.60"
    assert_selector "td", text: "$1,870.20", count: 2
    assert_text "October 1, 2026"
    assert_text "May 7, 2027"
    assert_text "October 4, 2027"

    click_link "Add deadline"
    select "Rooming list due", from: "Deadline"
    fill_in_html_date "Due date", "2027-10-03"
    fill_in "Due time", with: "17:00"
    click_button "Save deadline"
    assert_text "Deadline saved."
    assert_text "October 3, 2027 at 5:00 pm America/New_York"

    record_term("deposit_derivation", "Ten percent on October 1, 2026, then two equal payments.")
    record_term("attrition", "Unsold rooms follow the base rate plus 16.5% tax.")
    record_term(
      "deposit_refund",
      "The Hotel later clarified that the initial deposit may be refunded.",
      original: "The initial deposit is nonrefundable."
    )
    record_term("destination_fee", "The $150 destination fee is waived.")
    record_term("additional_nights", "Additional nights are available on request.")
    record_term("early_departure", "Early departure follows the Hotel's governing provision.")
    within("#hotel-term-cancellation") { click_button "Reviewed — none" }
    assert_text "Reviewed — none recorded."
    within("#hotel-term-cancellation") { assert_text "Reviewed — none" }
    within("#hotel-term-deposit_refund") { click_link "Edit term" }
    assert_field "Original wording", with: "The initial deposit is nonrefundable."
    assert_field "Governing wording", with: "The Hotel later clarified that the initial deposit may be refunded."
    find("#hotel-step-agreement").click

    %w[deposit_derivation attrition deposit_refund destination_fee additional_nights early_departure].each do |kind|
      within("#hotel-term-#{kind}") { assert_text "Recorded" }
    end

    click_link "Hotel review"
    fill_in_html_date "Evidence date", "2026-09-30"
    fill_in "Channel", with: "email"
    fill_in "Reference note", with: "Confirmed the Hotel terms."
    fill_in "Confirmed without a Supplier identifier", with: "No hotel number was issued."
    click_button "Confirm Supplier agreement"
    assert_text "Supplier confirmed."

    find("#hotel-step-rates").click
    fill_in "Standard room night base", with: "199"
    click_button "Save Supplier rates"
    assert_text "Lodging agreement definitions are immutable after Supplier confirmation"
    find("#hotel-step-agreement").click
    assert_text "$173.00"
    assert_no_text "$199.00"

    @departure.reload.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    find("#hotel-step-agreement").click
    click_link "Hotel review"
    check "Activate this confirmed Hotel agreement with the elapsed date."
    click_button "Activate arrangement"
    assert_text "Arrangement activated."
    assert_selector "#hotel-agreement-role", text: "Current governing agreement"
    assert_selector "#hotel-agreement-activation", text: "Activated"
    assert_no_selector "#hotel-step-stay"
    assert_no_selector "#hotel-step-inventory"
    assert_no_selector "#hotel-step-rates"
    assert_text "$173.00"
    item_path = current_path

    click_button "Create successor draft"
    assert_text "Successor draft version 2 created."
    assert_equal item_path, current_path
    assert_selector "#hotel-agreement-role", text: "Proposed successor draft"
    assert_selector "#hotel-agreement-lineage", text: "Based on current v1"
    assert_selector "#hotel-agreement-confirmation", text: "Not Supplier confirmed"
    assert_selector "#hotel-agreement-activation", text: "Not yet activated"
    assert_link "View current agreement"

    find("#hotel-step-rates").click
    fill_in "Standard room night base", with: "180"
    click_button "Save Supplier rates"
    assert_text "Supplier rates saved."
    find("#hotel-step-agreement").click
    assert_text "$180.00"
    click_link "View current agreement"
    assert_selector "#hotel-agreement-role", text: "Current governing agreement"
    assert_text "$173.00"
    assert_no_text "$180.00"
    click_link "View proposed successor"
    assert_selector "#hotel-agreement-role", text: "Proposed successor draft"
    assert_text "$180.00"

    click_link "Hotel review"
    fill_in_html_date "Evidence date", "2026-10-02"
    fill_in "Channel", with: "email"
    fill_in "Reference note", with: "Confirmed the successor terms."
    fill_in "Confirmed without a Supplier identifier", with: "No hotel number was issued."
    click_button "Confirm Supplier agreement"
    assert_text "Supplier confirmed."
    check "Activate this confirmed Hotel agreement with the elapsed date."
    click_button "Activate arrangement"
    assert_text "Arrangement activated."
    assert_selector "#hotel-agreement-role", text: "Current governing agreement"
    assert_text "$180.00"

    select "v1 · Superseded agreement", from: "Exact version"
    click_button "Show version" if page.has_button?("Show version", wait: 1)
    assert_selector "#hotel-agreement-role", text: "Superseded agreement"
    assert_text "$173.00"
    assert_no_text "$180.00"
    assert_no_selector "#hotel-step-stay"
    assert_no_text "Create Client Service"
    assert_no_text "Connect Client Service"
  end

  private

  def record_deposit(amount, due_on)
    click_link "Add deposit"
    fill_in "Amount", with: amount
    fill_in_html_date "Due date", due_on
    click_button "Save deposit"
    assert_text "Deposit saved."
  end

  def record_term(kind, wording, original: nil)
    within("#hotel-term-#{kind}") { click_link "Add wording" }
    choose "This Hotel stay" if page.has_field?("term-scope-stay", type: "radio", wait: 0)
    fill_in "Governing wording", with: wording
    fill_in "Original wording", with: original if original
    fill_in "Supplier source", with: "Hilton agreement"
    click_button "Save term"
    assert_text "Agreement term saved."
  end
end
