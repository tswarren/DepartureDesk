require "test_helper"

# S-25: starting a booking from the Departure's Bookings tab, for a client
# found in the directory or created there (CLT-02, CLT-05, CLT-09, OVR-02, BKG-05).
class DepartureNewBookingTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :trips)
    @departure = @alpha.departure
  end

  test "the roster offers New booking, and a search finds a client with their trip on this Departure" do
    sign_in_as @staff
    get departure_bookings_path(@departure)
    assert_select "a[href='#{new_departure_booking_path(@departure)}']", text: "New booking"

    get new_departure_booking_path(@departure, q: "Bennett")
    item = css_select("ul[aria-label='Matching clients'] li").find { |li| li.text.include?("Sofia Bennett") }
    trip = @alpha.trips.fetch("BK-104")
    assert_includes item.text, "travels with"
    assert_includes item.text, "Has trip #{trip.trip_reference} on this Departure"
    assert_select "button", text: "Book for Sofia Bennett"
  end

  test "booking for a found client puts the booking on their trip and opens the travelers step" do
    sign_in_as @staff
    trip = @alpha.trips.fetch("BK-104")
    assert_no_difference -> { ClientTrip.count } do
      post departure_bookings_path(@departure), params: { client_id: trip.client_id }
    end
    booking = trip.client_bookings.order(:sequence).last
    assert_redirected_to client_booking_path(booking, step: "travelers")
    assert_equal "draft", booking.status
  end

  test "a new client who is traveling becomes a client, a Self traveler and the booking's first traveler, on a new trip" do
    sign_in_as @staff
    post departure_bookings_path(@departure), params: { client_person: { first_name: "Jun", last_name: "Okafor", traveling: "1", date_of_birth: "1988-04-12" } }
    client = @agency.clients.joins(:client_person).find_by!(client_people: { first_name: "Jun", last_name: "Okafor" })
    booking = client.client_trips.sole.client_bookings.sole
    assert_redirected_to client_booking_path(booking, step: "travelers")
    assert_equal @departure, booking.client_trip.departure
    row = booking.booking_travelers.sole
    assert_equal [ "Jun", "Okafor", Date.new(1988, 4, 12) ], row.traveler.values_at(:given_names, :surname, :date_of_birth)
    assert_equal "self", client.traveler_links.sole.relationship
  end

  test "a possible duplicate asks for review, then starts the booking once a reason is given" do
    sign_in_as @staff
    names = { first_name: "Sofia", last_name: "Bennett", traveling: "0" }
    assert_no_difference -> { ClientPerson.count } do
      post departure_bookings_path(@departure), params: { client_person: names }
    end
    assert_response :unprocessable_entity
    assert_select "h2", text: "Possible duplicates"
    token = css_select("input[name=acknowledgement_token]").sole["value"]

    assert_difference -> { ClientPerson.count } => 1, -> { ClientBooking.count } => 1 do
      post departure_bookings_path(@departure), params: { client_person: names, acknowledgement_token: token, acknowledgement_reason: "confirmed_distinct" }
    end
  end

  test "a Departure that isn't on sale refuses, and nothing is left behind" do
    @departure.update_columns(sales_status: "draft")
    sign_in_as @staff
    assert_no_difference [ -> { ClientPerson.count }, -> { Client.count }, -> { Traveler.count }, -> { ClientTrip.count }, -> { ClientBooking.count } ] do
      post departure_bookings_path(@departure), params: { client_person: { first_name: "Jun", last_name: "Okafor", traveling: "1" } }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /can't take a new booking/
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get new_departure_booking_path(@departure)
    assert_response :not_found
  end
end
