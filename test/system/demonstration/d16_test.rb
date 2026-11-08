require "application_system_test_case"

# Demonstration case D16 (first-slice charter). Rules: UI acceptance, CLT-15, BKG-45.
class DemonstrationD16Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @scenario = AlphaScenario.load!(bookings: :trips)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D16: drafts save with required fields missing" do
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)

    visit new_departure_path
    wait_for_turbo
    fill_in "Name", with: "Spring sampler"
    select "No time zone", from: "Time zone"
    fill_in "Operating currency", with: ""
    click_button "Save departure"
    assert_text "Departure saved."
    within("#ready-to-sell") { assert_text "Enter a start date and an end date." }

    visit new_departure_arrangement_path(@scenario.agency.departures.find_by!(name: "Spring sampler"))
    wait_for_turbo
    select "Alpha Cruises", from: "Supplier"
    click_button "Save as Draft"
    assert_text "Draft"

    trip = @alpha.trips.fetch("BK-101")
    visit client_trip_path(trip)
    click_button "New booking"
    assert_text "created as a draft."
    within("#add-placeholder") do
      fill_in "Placeholder", with: "Guest 2"
      click_button "Add placeholder"
    end
    assert_text "Traveler added."
    within("nav[aria-label='Booking steps']") { click_link "Accept and confirm" }
    click_button "Confirm booking"

    within("#form-error-summary") do
      assert_link "Record the client's acceptance of the current price and terms.", href: "#acceptance"
      assert_link "Replace Guest 2 with a traveler who has a legal name and date of birth."
      assert_link "Choose cabin."
      click_link "Replace Guest 2 with a traveler who has a legal name and date of birth."
    end
    booking = trip.client_bookings.sole
    assert_equal "draft", booking.status
    assert_current_path client_booking_path(booking, step: "travelers")
    assert_selector "#booking-traveler-#{booking.booking_travelers.sole.id}", text: "Guest 2"
  end
end
