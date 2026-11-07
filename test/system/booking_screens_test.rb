require "application_system_test_case"

# Slice 1 step 6b screens S-25, S-26 and the S-17 additions, at desktop width and 375px.
class BookingScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @scenario = AlphaScenario.load!(bookings: :held)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "S-25, S-26 and the inventory page reflow at 375px without page overflow" do
    paths = [
      departure_bookings_path(@alpha.departure),
      client_booking_path(@alpha.bookings.fetch("BK-104")),
      client_booking_path(@alpha.bookings.fetch("BK-101")),
      client_trip_path(@alpha.trips.fetch("BK-105")),
      departure_inventory_path(@alpha.departure),
      new_client_booking_acceptance_path(@alpha.bookings.fetch("BK-104")),
      departure_client_terms_path(@alpha.departure)
    ]
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      paths.each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_selector "nav[aria-label='Breadcrumb']"
        assert_no_page_overflow
      end
    end
  end

  test "a confirmed booking with its acceptance and supplier cost reflows at 375px" do
    booking = @alpha.bookings.fetch("BK-104")
    RecordBookingAcceptance.new(agency: @scenario.agency, actor: @scenario.actor, booking:,
      attributes: { accepted_by: "Sofia Bennett", acceptance_method: "phone", note: "Accepted by phone." }).call
    ConfirmClientBooking.new(agency: @scenario.agency, actor: @scenario.actor, booking: booking.reload).call
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      visit client_booking_path(booking)
      wait_for_turbo
      assert_selector "#supplier-cost"
      within("#acceptance") { assert_text "Covers the current price and terms" }
      assert_no_page_overflow
    end
  end

  test "staff book a trip: add travelers, choose a cabin, hold space and see the price" do
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    trip = @alpha.trips.fetch("BK-105")
    visit client_trip_path(trip)
    click_button "New booking"
    assert_text "created as a draft."
    %w[Mateo Elena].each do |name|
      within("#travelers") do
        select "#{name} Rivera", from: "Traveler"
        select "Adult", from: "Traveler type"
        click_button "Add traveler"
      end
      within("#travelers table") { assert_selector "th", text: "#{name} Rivera" }
    end
    cabin = @alpha.offering.choices.find_by!(name: "Cabin")
    within("#choice-#{cabin.id}") do
      select "I01", from: "Option to add"
      click_button "Add"
    end
    assert_text "Choice saved."
    within("#prices") { assert_text "$5,170.00" }
    within("#hold") { click_button "Hold space" }
    assert_text "Space held."
    within("#status") { assert_text "Held until Jan 13, 2027, 11:59 p.m." }
  end
end
