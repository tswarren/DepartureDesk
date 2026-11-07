require "test_helper"

# S-22 to S-24: travelers, links and Client Trips are baseline work (ACC-30).
class TravelersAndTripsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :trips)
    @trip = @alpha.trips.fetch("BK-104")
    @client = @trip.client
  end

  test "the client profile lists its travelers by relationship and its trips" do
    sign_in_as @staff
    get client_person_path(@client.client_person)
    assert_select "#travelers th[scope=row]", text: "Sofia Bennett"
    assert_select "#travelers td", text: "Self"
    assert_select "#travelers tbody tr", count: 4
    assert_select "#trips a", text: @trip.trip_reference
    assert_select "#trips a", text: "New trip"
  end

  test "baseline staff create a client who is also traveling, then add a traveler from the profile" do
    sign_in_as @staff
    post clients_path, params: { source: "individual", also_traveling: "1", client_person: { first_name: "Jun", last_name: "Okafor" } }
    client = @agency.client_people.find_by!(first_name: "Jun").client
    assert_equal [ "self" ], client.traveler_links.pluck(:relationship)

    post travelers_path, params: { client_id: client.id, relationship: "family_member",
      traveler: { given_names: "Ada", surname: "Okafor", date_of_birth: "2019-04-01" } }
    assert_redirected_to client_person_path(client.client_person)
    assert_equal Date.new(2019, 4, 1), client.travelers.find_by!(given_names: "Ada").date_of_birth
  end

  test "an invalid traveler re-renders with the error on its field" do
    sign_in_as @staff
    post travelers_path, params: { traveler: { surname: "Okafor", date_of_birth: "2019-02-30" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#traveler_date_of_birth']"
    assert_select "#traveler_date_of_birth[aria-invalid=true]"
  end

  test "staff find and link an existing traveler, then unlink them" do
    elena = @alpha.trips.fetch("BK-105").client.travelers.find_by!(given_names: "Elena")
    sign_in_as @staff
    get new_traveler_link_path(client_id: @client.id, q: "elena")
    assert_select "th[scope=row] a", text: "Elena Rivera"
    post traveler_links_path, params: { client_id: @client.id, traveler_id: elena.id, relationship: "other" }
    assert_redirected_to client_person_path(@client.client_person)
    link = @client.traveler_links.find_by!(traveler: elena)
    delete traveler_link_path(link)
    assert_not TravelerLink.exists?(link.id)
  end

  test "a trip shows its reference, responsible client, Departure and status, and its Departure can change" do
    sign_in_as @staff
    get client_trip_path(@trip)
    assert_select "h1", text: @trip.trip_reference
    assert_select "dd", text: /Not booked/
    assert_select "dd a", text: "#{@alpha.departure.departure_reference} · #{@alpha.departure.name}"

    post client_trips_path, params: { client_trip: { client_id: @client.id, departure_id: "" } }
    trip = @client.client_trips.where(departure_id: nil).sole
    assert_redirected_to client_trip_path(trip)
    patch client_trip_path(trip), params: { client_trip: { departure_id: @alpha.departure.id, lock_version: trip.lock_version } }
    assert_equal @alpha.departure, trip.reload.departure
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get client_trip_path(@trip)
    assert_response :not_found
    get traveler_path(@client.travelers.first)
    assert_response :not_found
    get new_client_trip_path(client_id: @client.id)
    assert_response :not_found
  end
end
