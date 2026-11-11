require "application_system_test_case"

# Demonstration case D15 (first-slice charter, as amended by D-99 (1)).
# Rules: ACC-14, ACC-15, ACC-31, CLT-25, DEP-07, DEP-10, CMN-19, CMN-52.
class DemonstrationD15Test < ApplicationSystemTestCase
  COST_WORDS = /supplier cost|commission|margin|rate table|cost line/i

  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :none)
    @alpha = @scenario.alpha
    set_clock Time.utc(2027, 2, 2, 15)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D15: the reseller sees only its scope" do
    # 1. Dana lands on Coral Coast's home: the published package and no booking.
    sign_in_from_browser(@alpha.reseller_user, password: M1DirectoryScenario::PASSWORD)
    assert_selector "h1", text: "Offers and bookings"
    assert_link @alpha.offering.name
    assert_text "No bookings yet."
    assert_no_link "Departures"
    assert_no_link "Clients"

    # 2. She creates Mateo, Elena and Luca, the trip and BK-105, and holds.
    find("a[aria-label='Start a booking on #{@alpha.offering.name}']").click
    fill_in "First name", with: "Mateo"
    fill_in "Last name", with: "Rivera"
    assert_checked_field "The client is also traveling"
    fill_in_html_date "Date of birth (optional)", "1990-05-11"
    click_button "Start booking"
    assert_text "created as a draft."
    booking = ResellerScope.new(@alpha.reseller_user).bookings.sole
    select "Adult", from: "Traveler type for Mateo Rivera"
    find("input[aria-label='Save type for Mateo Rivera']").click
    assert_text "Traveler updated."
    assert_no_field "Or find a traveler in the agency"
    [ [ "Elena", "1991-10-30", "Adult" ], [ "Luca", "2024-06-20", "Child 0–4" ] ].each do |name, born, type|
      within("#new-traveler") do
        fill_in "Given names", with: name
        fill_in_html_date "Date of birth (optional)", born
        select "Family member", from: "Relationship to Mateo Rivera"
        select type, from: "Traveler type"
        click_button "Add new traveler"
      end
      assert_text "Traveler added and linked to Mateo Rivera."
    end

    within("nav[aria-label='Booking steps']") { click_link "Rooms and options" }
    choices = @alpha.offering.choices.index_by(&:name)
    within("#choice-#{choices.fetch("Cabin").id}") do
      select "O01", from: "Option to add"
      click_button "Add"
    end
    assert_text "Choice saved."
    within("#choice-#{choices.fetch("Nov 5 hotel room").id}") do
      select "Garden Queen", from: "Option to add"
      click_button "Add"
    end
    assert_text "Choice saved."
    within("#choice-#{choices.fetch("Private Miami tour").id}") do
      select "Private Miami tour, Nov 5", from: "Option to add"
      uncheck "Elena Rivera"
      click_button "Add"
    end
    assert_text "Choice saved."

    within("nav[aria-label='Booking steps']") { click_link "Price and installments" }
    within("#prices tbody tr", text: "O01") { assert_text "$7,105.00" }
    assert_no_selector "#adjust-installments"
    within("nav[aria-label='Booking steps']") { click_link "Hold space" }
    within("#hold") { click_button "Hold space" }
    assert_text "Space held."

    # 3. She records Mateo's in-person acceptance and confirms.
    within("nav[aria-label='Booking steps']") { click_link "Accept and confirm" }
    within("#acceptance") { click_link "Record acceptance" }
    choose "In person"
    fill_in "Note (optional)", with: "Mateo Rivera accepted the price and terms in person."
    click_button "Record acceptance"
    assert_text "Acceptance recorded."
    click_button "Confirm booking"
    assert_text "Booking confirmed."
    booking.reload
    assert booking.status_confirmed?
    assert_equal [ @alpha.reseller, @alpha.reseller ], [ booking.owner_reseller, booking.seller_reseller ]
    assert_equal 710_500, booking.client_charge.lines.select { |line| line.description.include?("O01") }.sum(&:amount_minor_units)

    # R-04: she issues and downloads BK-105's confirmation; its invoice isn't offered (DOC-24, D-100).
    @scenario.agency.update!(contact_email: "bookings@harbor.example") if @scenario.agency.contact_email.blank?
    visit reseller_client_booking_path(booking, step: "summary")
    within("#documents") do
      assert_no_text "Invoice"
      accept_confirm { click_button "Issue booking confirmation" }
    end
    assert_text "Booking confirmation issued."
    confirmation = booking.document_versions.reload.sole
    assert_equal "Coral Coast Travel", confirmation.snapshot["booked_through"]
    within("#documents") { assert_selector "a[aria-label='Download booking confirmation #{confirmation.number}']" }

    # 4. Charge lines, installments and balance, with no supplier cost, commission or margin.
    within("nav[aria-label='Booking steps']") { click_link "Money" }
    within("#booking-balance") { assert_text "Still due" }
    within("#booking-installments") { assert_selector "table" }
    assert_text "Payments are recorded by #{@scenario.agency.name}."
    assert_no_link "Record a payment"
    [ reseller_client_booking_path(booking), reseller_client_booking_path(booking, step: "confirm"), reseller_client_booking_path(booking, step: "money"),
      reseller_root_path, reseller_offer_path(@alpha.offering) ].each do |path|
      visit path
      assert_no_match COST_WORDS, page.html, path
    end

    # 5. Recording a payment is refused; an agency-owned booking is not found
    # (BK-101 and BK-104, staff's, are checked against the default seed in
    # the controller tests).
    visit new_client_trip_payment_path(booking.client_trip)
    assert_current_path reseller_root_path
    assert_text "You are not allowed to do that."
    staff_booking = StartClientBooking.new(agency: @scenario.agency, actor: @scenario.actor, departure: @alpha.departure,
      person: { first_name: "Nadia", last_name: "Rowan" }).call.record
    [ staff_booking, *ClientBooking.where(agency: @scenario.agency).where.not(id: booking.id) ].each do |other|
      visit reseller_client_booking_path(other)
      assert_text(/RecordNotFound|doesn't exist|Not Found/i)
    end
  end
end
