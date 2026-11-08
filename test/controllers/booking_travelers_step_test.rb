require "test_helper"

# S-26 step 1: adding the client's travelers at once, each with the type
# staff choose (CLT-13, BKG-21), and moving them in guest order.
class BookingTravelersStepTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :held)
    @trip = @alpha.trips.fetch("BK-104")
    @adult = @agency.traveler_types.find_by!(name: "Adult")
    @child = @agency.traveler_types.find_by!(name: "Child")
  end

  test "the step lists the client's travelers with relationship and age at departure, and no type chosen" do
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @trip).call.record
    sign_in_as @staff
    get client_booking_path(booking, step: "travelers")
    item = css_select("#add-travelers li").find { |li| li.text.include?("Ava Bennett") }
    assert_includes item.text, "11 at departure"
    assert_includes item.text, "Family member"
    ava = @trip.client.travelers.find_by!(given_names: "Ava")
    assert_select "select#traveler_type_#{ava.id} option[selected]", count: 0
    assert_select "#someone-else h4", text: "A new traveler"
  end

  test "ticked travelers are added in order with their types; unticked ones are not" do
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @trip).call.record
    people = @trip.client.travelers.index_by(&:given_names)
    sign_in_as @staff
    post client_booking_traveler_batch_path(booking), params: { travelers: {
      people.fetch("Sofia").id => { add: "1", traveler_type_id: @adult.id },
      people.fetch("Ava").id => { add: "1", traveler_type_id: @child.id },
      people.fetch("Marcus").id => { add: "0", traveler_type_id: @adult.id }
    } }
    assert_redirected_to client_booking_path(booking, step: "travelers", anchor: "travelers")
    rows = booking.booking_travelers.reload
    assert_equal [ [ "Sofia Bennett", "Adult", 1 ], [ "Ava Bennett", "Child", 2 ] ], rows.map { |row| [ row.display_name, row.traveler_type.name, row.position ] }
  end

  test "nothing ticked is refused, and another agency's traveler is ignored" do
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @trip).call.record
    sign_in_as @staff
    post client_booking_traveler_batch_path(booking), params: { travelers: { SecureRandom.uuid_v7 => { add: "1" } } }
    follow_redirect!
    assert_select ".dd-alert--danger", text: /Tick at least one traveler/
    assert_empty booking.booking_travelers.reload
  end

  test "moving a traveler up swaps guest order, and unit positions follow" do
    booking = @alpha.bookings.fetch("BK-104")
    sign_in_as @staff
    ava, milo = booking.booking_travelers.to_a.values_at(2, 3)
    post client_booking_traveler_move_path(booking, milo), params: { direction: "up" }
    assert_redirected_to client_booking_path(booking, step: "travelers", anchor: "travelers")
    assert_equal [ 3, 4 ], [ milo.reload.position, ava.reload.position ]
    cabin = booking.choice_selections.reload.find { |selection| selection.choice.name == "Cabin" }
    occupants = cabin.occupants.reload.sort_by { |occupant| occupant.position.to_i }.map { |occupant| occupant.booking_traveler.display_name }
    assert_equal "Milo Bennett", occupants[2]
  end

  test "a new traveler is created, linked to the client and added in one step" do
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @trip).call.record
    sign_in_as @staff
    get client_booking_path(booking, step: "travelers")
    assert_select "#new-traveler input[name='traveler[surname]'][value='Bennett']"

    post client_booking_traveler_additions_path(booking), params: {
      traveler: { given_names: "June", surname: "Bennett", date_of_birth: "2012-06-01" }, relationship: "family_member", traveler_type_id: @child.id
    }
    assert_redirected_to client_booking_path(booking, step: "travelers", anchor: "travelers")
    row = booking.booking_travelers.reload.sole
    assert_equal [ "June Bennett", "Child", Date.new(2012, 6, 1) ], [ row.display_name, row.traveler_type.name, row.traveler.date_of_birth ]
    assert_equal "family_member", @trip.client.traveler_links.find_by!(traveler: row.traveler).relationship
  end

  test "a traveler found in the agency is linked to the client and added" do
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @trip).call.record
    nadia = @alpha.trips.fetch("BK-101").client.travelers.find_by!(given_names: "Nadia")
    sign_in_as @staff
    get client_booking_path(booking, step: "travelers", traveler_q: "Nadia")
    assert_select "ul[aria-label='Matching travelers'] li", text: /Nadia Rowan/
    get client_booking_path(booking, step: "travelers", traveler_q: "Ava")
    assert_select "ul[aria-label='Matching travelers']", count: 0

    post client_booking_traveler_additions_path(booking), params: { traveler_id: nadia.id, relationship: "other", traveler_type_id: @adult.id }
    assert_equal [ nadia.id ], booking.booking_travelers.reload.map(&:traveler_id)
    assert @trip.client.traveler_links.exists?(traveler: nadia, relationship: "other")
  end

  test "a new traveler with no name adds nothing" do
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @trip).call.record
    sign_in_as @staff
    assert_no_difference [ -> { Traveler.count }, -> { TravelerLink.count }, -> { BookingTraveler.count } ] do
      post client_booking_traveler_additions_path(booking), params: { traveler: { given_names: "", surname: "" }, relationship: "family_member" }
    end
    follow_redirect!
    assert_select ".dd-alert--danger"
  end
end
