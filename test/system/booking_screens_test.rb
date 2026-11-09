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
      *BookingProgress::STEPS.map { |step| client_booking_path(@alpha.bookings.fetch("BK-104"), step:) },
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
    within("#add-travelers") do
      assert_text "Mateo Rivera"
      uncheck "Luca Rivera"
      select "Adult", from: "Traveler type for Mateo Rivera"
      select "Adult", from: "Traveler type for Elena Rivera"
      click_button "Add ticked travelers"
    end
    assert_text "Travelers added."
    within("#travelers table") do
      assert_selector "th", text: "Mateo Rivera"
      assert_selector "th", text: "Elena Rivera"
      assert_no_selector "th", text: "Luca Rivera"
    end
    find("button[aria-label='Move Elena Rivera up']").click
    assert_text "Order updated."
    within("#travelers tbody tr:first-child") { assert_text "Elena Rivera" }
    click_link "Next: rooms and options"
    cabin = @alpha.offering.choices.find_by!(name: "Cabin")
    within("#choice-#{cabin.id}") do
      select "I01", from: "Option to add"
      click_button "Add"
    end
    assert_text "Choice saved."
    within("nav[aria-label='Booking steps']") { click_link "Price and hold" }
    within("#prices") { assert_text "$5,170.00" }
    within("#hold") { click_button "Hold space" }
    assert_text "Space held."
    within("#status") { assert_text "Held until Jan 13, 2027, 11:59 p.m." }
  end

  test "staff start a booking from the Bookings tab for a new client who is traveling" do
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    visit departure_bookings_path(@alpha.departure)
    click_link "New booking"
    fill_in "Find a client", with: "Rivera"
    click_button "Search"
    assert_button "Book for Mateo Rivera"
    [ 1400, 375 ].each do |width|
      resize_window(width)
      assert_no_page_overflow
    end
    resize_window(1400)

    fill_in "First name", with: "Jun"
    fill_in "Last name", with: "Okafor"
    assert_field "Date of birth (optional)"
    choose "They are not traveling"
    assert_no_field "Date of birth (optional)"
    choose "They are also traveling"
    fill_in_html_date "Date of birth (optional)", "1988-04-12"
    click_button "Create client and start booking"
    assert_text "started on trip"
    assert_selector "nav[aria-label='Booking steps'] a[aria-current=step]", text: /Travelers/
    within("#travelers table") { assert_selector "th", text: "Jun Okafor" }
  end

  test "staff add extra nights as a range of nights" do
    booking = @alpha.bookings.fetch("BK-105")
    nights = @alpha.offering.choices.find_by!(name: "Extension nights")
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    visit client_booking_path(booking, step: "rooms")
    within("#nights-#{nights.id}") do
      assert_checked_field "The same room as Nov 5 hotel room"
      assert_no_select "Room"
      select "Nov 2", from: "From the night of"
      select "Nov 3", from: "Through the night of"
      click_button "Add nights"
    end
    assert_text "Nights added."
    within("#choice-#{nights.id}") do
      %w[Nov\ 2 Nov\ 3].each { |night| assert_text "#{night} Garden Queen" }
    end

    within("#nights-#{nights.id}") do
      choose "One room with the travelers I choose"
      select "Harbor Double", from: "Room"
      select "Nov 1", from: "From the night of"
      select "Nov 1", from: "Through the night of"
      assert_text "The same travelers as"
      click_button "Add nights"
    end
    assert_text "Nights added."
    within("#choice-#{nights.id}") { assert_text "Nov 1 Harbor Double" }
  end

  test "staff add a new traveler and a traveler found in the agency without leaving the booking" do
    booking = @alpha.bookings.fetch("BK-105")
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    visit client_booking_path(booking, step: "travelers")
    within("#new-traveler") do
      fill_in "Given names", with: "Rosa"
      fill_in "Surname", with: "Rivera"
      select "Adult", from: "Traveler type"
      click_button "Add new traveler"
    end
    assert_text "Traveler added and linked to Mateo Rivera."
    within("#travelers table") { assert_selector "th", text: "Rosa Rivera" }

    fill_in "Or find a traveler in the agency", with: "Nadia"
    click_button "Find"
    within("ul[aria-label='Matching travelers']") do
      select "Adult", from: "Traveler type for Nadia Rowan"
      find("input[aria-label='Link and add Nadia Rowan']").click
    end
    assert_text "Traveler added and linked"
    within("#travelers table") { assert_selector "th", text: "Nadia Rowan" }
    [ 1400, 375 ].each do |width|
      resize_window(width)
      assert_no_page_overflow
    end
  end

  test "staff replace a placeholder with one of the client's travelers, who keeps its cabin" do
    booking = @alpha.bookings.fetch("BK-105")
    luca = booking.booking_travelers.find { |row| row.display_name == "Luca Rivera" }
    luca.update_columns(traveler_id: nil, placeholder_label: "Guest 3")
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    visit client_booking_path(booking, step: "travelers")
    within("#booking-traveler-#{luca.id}") do
      select "Luca Rivera", from: "Replace Guest 3 with"
      find("input[aria-label='Replace Guest 3']").click
    end
    assert_text "Guest 3 replaced."
    within("#booking-traveler-#{luca.id}") { assert_text "Luca Rivera" }
    visit client_booking_path(booking, step: "rooms")
    within("#choices") { assert_text "Luca Rivera" }
  end
end
