require "test_helper"

# S-26 step 2: rooms follow the cabin, and extra nights are added as a range (BKG-14, question 19).
class BookingRoomsStepTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :held)
    @offering = @alpha.offering
    @cabin = @offering.choices.find_by!(name: "Cabin")
    @room = @offering.choices.find_by!(name: "Nov 5 hotel room")
    @nights = @offering.choices.find_by!(name: "Extension nights")
    @adult = @agency.traveler_types.find_by!(name: "Adult")
  end

  test "a new room starts with the matching cabin's travelers" do
    trip = @alpha.trips.fetch("BK-105")
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip:).call.record
    rows = trip.client.travelers.map do |traveler|
      SaveBookingTraveler.new(agency: @agency, actor: @staff, booking:, attributes: { traveler_id: traveler.id, traveler_type_id: @adult.id }).call.record
    end
    SaveChoiceSelection.new(agency: @agency, actor: @staff, booking:, attributes: {
      offering_option_id: @cabin.options.find_by!(label: "O01").id, occupant_ids: rows.first(2).map(&:id)
    }).call

    sign_in_as @staff
    get client_booking_path(booking, step: "rooms")
    form = css_select("#new-selection-#{@room.id}").sole
    checked = form.css("input[type=checkbox][checked]").map { |input| input["value"] }
    assert_equal rows.first(2).map(&:id), checked
    assert_includes form.text, "The same travelers as"
  end

  test "extra nights go in as one room type over a range of nights, each night its own unit" do
    booking = @alpha.bookings.fetch("BK-105")
    sign_in_as @staff
    get client_booking_path(booking, step: "rooms")
    assert_select "#nights-#{@nights.id} select[name='selection_range[kind]'] option", text: "Harbor Double"
    occupants = booking.booking_travelers.map(&:id)

    post client_booking_selection_range_path(booking), params: { choice_id: @nights.id, selection_range: {
      choice_id: @nights.id, kind: "Harbor Double", from: "2027-11-01", through: "2027-11-03", occupant_ids: occupants
    } }
    assert_redirected_to client_booking_path(booking, step: "rooms", anchor: "choice-#{@nights.id}")
    follow_redirect!
    assert_equal [], css_select(".dd-alert--danger").map(&:text)
    added = booking.choice_selections.reload.select { |selection| selection.choice.id == @nights.id }
    assert_equal [ "Nov 1 Harbor Double", "Nov 2 Harbor Double", "Nov 3 Harbor Double" ], added.map { |selection| selection.option.label }.sort
    assert(added.all? { |selection| selection.occupants.map(&:booking_traveler_id).sort == occupants.sort })
  end

  test "a range with no matching night, or the wrong way round, adds nothing" do
    booking = @alpha.bookings.fetch("BK-105")
    sign_in_as @staff
    post client_booking_selection_range_path(booking), params: { choice_id: @nights.id, selection_range: {
      choice_id: @nights.id, kind: "Harbor Double", from: "2027-11-04", through: "2027-11-02"
    } }
    follow_redirect!
    assert_select ".dd-alert--danger", text: /on or after the first/
    assert(booking.choice_selections.reload.none? { |selection| selection.choice.id == @nights.id })
  end

  test "extra nights follow the booking's hotel rooms, each keeping its type and travelers (G14)" do
    trip = @alpha.trips.fetch("BK-101")
    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip:).call.record
    child = @agency.traveler_types.find_by!(name: "Child")
    rows = trip.client.travelers.index_by(&:given_names).transform_values do |traveler|
      SaveBookingTraveler.new(agency: @agency, actor: @staff, booking:, attributes: { traveler_id: traveler.id, traveler_type_id: traveler.given_names == "Iris" ? child.id : @adult.id }).call.record
    end
    garden = @room.options.find_by!(label: "Garden Queen")
    [ %w[Nadia Iris], %w[Theo] ].each do |names|
      SaveChoiceSelection.new(agency: @agency, actor: @staff, booking:, attributes: { offering_option_id: garden.id, occupant_ids: rows.values_at(*names).map(&:id) }).call
    end

    sign_in_as @staff
    get client_booking_path(booking, step: "rooms")
    form = css_select("#nights-#{@nights.id}").sole
    assert_includes form.text, "The same 2 rooms as Nov 5 hotel room"
    assert form.css("input[type=radio][value=rooms][checked]").any?
    rooms = form.css("input[name^='selection_range[rooms]']").group_by { |input| input["name"][/rooms\]\[(\d+)\]/, 1] }
      .transform_values { |inputs| { kind: inputs.find { |i| i["name"].end_with?("[kind]") }["value"], occupant_ids: inputs.select { |i| i["name"].end_with?("[occupant_ids][]") }.map { |i| i["value"] } } }

    post client_booking_selection_range_path(booking), params: { choice_id: @nights.id, selection_range: {
      choice_id: @nights.id, mode: "rooms", rooms:, from: "2027-11-04", through: "2027-11-04"
    } }
    follow_redirect!
    assert_equal [], css_select(".dd-alert--danger").map(&:text)
    added = booking.choice_selections.reload.select { |selection| selection.choice.id == @nights.id }
    assert_equal [ [ "Nov 4 Garden Queen", %w[Iris Nadia] ], [ "Nov 4 Garden Queen", %w[Theo] ] ],
      added.map { |selection| [ selection.option.label, selection.occupants.map { |occupant| occupant.booking_traveler.traveler.given_names }.sort ] }.sort
    assert_equal 38_000, booking.price_lines.reload.select { |line| added.map(&:id).include?(line.choice_selection_id) }.sum(&:amount_minor_units)
  end

  test "a confirmed booking says why it can't change and offers a new booking on its trip" do
    booking = @alpha.bookings.fetch("BK-105")
    RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking:, attributes: { accepted_by: "Mateo Rivera", acceptance_method: "phone", note: "Yes." }).call
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking:).call
    sign_in_as @staff
    get client_booking_path(booking, step: "travelers")
    assert_select "[role=status]", text: /confirmed, so its travelers and services can't change here/
    assert_select "#add-travelers", count: 0
    assert_select "#someone-else", count: 0
    post client_trip_bookings_path(booking.client_trip)
    assert_equal 2, booking.client_trip.client_bookings.reload.size
  end
end
