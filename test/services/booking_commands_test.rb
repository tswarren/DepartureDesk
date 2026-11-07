require "test_helper"

# Slice 1 step 6b: BKG-05, BKG-06, BKG-09 to BKG-11, BKG-14, BKG-16, BKG-23,
# CLT-13, CLT-15, DEP-05, INV-09, INV-17 to INV-21, INV-23, INV-39, D-88;
# step 6 plan questions 7, 8 and 14 to 21.
class BookingCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15) # 10 a.m. in New York
    @agency = agencies(:harbor)
    @agency.update_columns(default_timezone: AlphaFixture::TIME_ZONE)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :trips)
    @trip = @alpha.trips.fetch("BK-104")
    @types = @agency.traveler_types.index_by(&:name)
  end

  test "a booking is created on an On sale Departure, referenced from its trip, and its number is never reused (DEP-05, REF-04)" do
    first = create_booking!
    assert_equal "#{@trip.trip_reference}-1", first.booking_reference
    assert_equal [ @alpha.offering, @alpha.client_terms, "draft" ], [ first.offering, first.client_terms_version, first.status ]
    DiscardClientBooking.new(agency: @agency, actor: @staff, booking: first).call
    assert_equal "#{@trip.trip_reference}-2", create_booking!.booking_reference, "a discarded booking keeps its number (SC-REF-06)"

    ReturnDepartureToDraft.new(agency: @agency, actor: @admin, departure: @alpha.departure, reason: "Repricing", lock_version: @alpha.departure.reload.lock_version).call
    refused = assert_raises(AgencyCommand::Error) { create_booking! }
    assert_match(/isn't on sale, so it can't take a new booking: it is not Ready to sell/, refused.message)
  end

  test "prices are proposed per traveler by position and kept when the package's prices change (BKG-21, BKG-23)" do
    booking = bennett_booking!
    cabin = booking.price_lines.select { |line| line.choice_selection.option.label == "S01" }.sort_by { |line| line.booking_traveler.position }
    assert_equal [ 508_500, 508_500, 53_500, 53_500 ], cabin.map(&:amount_minor_units)
    assert_equal %w[guest_1 guest_2 guest_3 guest_4], cabin.map(&:occupancy_position)
    assert_equal 1_124_000, cabin.sum(&:amount_minor_units)

    s01 = @alpha.offering.choices.find_by!(name: "Cabin").options.find_by!(label: "S01")
    SaveOfferingPrice.new(agency: @agency, actor: @admin, departure: @alpha.departure, offering: @alpha.offering, option: s01,
      attributes: { occupancy_position: "guest_1", amount: "6000" }).call
    assert_equal 1_124_000, cabin_total(booking.reload), "a price change touches no booking"

    milo = traveler_row(booking, "Milo")
    SaveBookingTraveler.new(agency: @agency, actor: @staff, booking:, booking_traveler: milo, attributes: { traveler_type_id: @types.fetch("Child").id }, lock_version: milo.lock_version).call
    assert_equal 508_500, booking.reload.price_lines.find { |line| line.booking_traveler_id == traveler_row(booking, "Sofia").id && line.choice_selection.option.label == "S01" }.amount_minor_units,
      "unchanged contents keep their prices"
    assert_equal 15_000, booking.price_lines.find { |line| line.booking_traveler_id == milo.id && line.choice_selection.option.choice.name == "Private Miami tour" }.amount_minor_units,
      "the retyped traveler's line is proposed again at the current price"
  end

  test "a hold takes every service or none, names what can't be held, and lasts to 11:59 p.m. on its last day (BKG-09, BKG-11)" do
    booking = bennett_booking!
    HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call
    booking.reload
    assert_equal :held, booking.hold_state.first
    assert_equal Time.utc(2027, 1, 14, 4, 59), booking.hold_state.last, "Jan 13 at 11:59 p.m. in New York"
    held = booking.inventory_allocations.map { |allocation| [ allocation.inventory_group.label, allocation.quantity ] }.sort
    assert_equal [ [ "Nov 4 Harbor Double", 1 ], [ "Nov 5 Harbor Double", 4 ], [ "Private Miami tour", 3 ], [ "S01", 4 ] ], held,
      "Milo uses no tour position; the on-request Nov 2 and 3 nights take nothing"

    other = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @alpha.trips.fetch("BK-101")).call.record
    row = SaveBookingTraveler.new(agency: @agency, actor: @staff, booking: other, attributes: { placeholder_label: "Guest 1", traveler_type_id: @types.fetch("Adult").id }).call.record
    select!(other, "Extension nights", "Nov 4 Harbor Double", [ row ])
    select!(other, "Cabin", "V01", [ row ])
    refused = assert_raises(AgencyCommand::Error) { HoldBookingSpace.new(agency: @agency, actor: @staff, booking: other).call }
    assert_match(/Extension nights 1: Nov 4 Harbor Double: no Nov 4 Harbor Double space is left/, refused.message)
    assert_empty other.inventory_allocations.reload, "nothing is held when any part fails"

    set_clock Time.utc(2027, 1, 14, 5)
    assert_equal :expired, booking.reload.hold_state.first
    assert_equal 0, @alpha.arrangements.fetch(:cruise).inventory_groups.find_by!(label: "S01").unit_shells.sum(&:positions_used), "a lapsed hold stops counting"
  end

  test "a hold extends once, and an edit that replaces it keeps the expiry and the extension (BKG-09, questions 15 and 20)" do
    booking = bennett_booking!
    HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call
    ExtendBookingHold.new(agency: @agency, actor: @staff, booking:).call
    extended = booking.reload.hold_state.last
    assert_equal Time.utc(2027, 1, 16, 4, 59), extended

    ava = traveler_row(booking, "Ava")
    tour = booking.choice_selections.find { |selection| selection.option.choice.name == "Private Miami tour" }
    SaveChoiceSelection.new(agency: @agency, actor: @staff, booking:, selection: tour, attributes: { occupant_ids: booking.booking_travelers.map(&:id) - [ ava.id ] }).call
    replacement = booking.reload.consuming_allocations.find { |allocation| allocation.choice_selection_id == tour.id }
    assert_equal 2, replacement.quantity
    assert_equal [ extended, true ], [ replacement.hold_expires_at, replacement.hold_extended_at.present? ]
    assert replacement.replaces.state_released?
    refused = assert_raises(AgencyCommand::Error) { ExtendBookingHold.new(agency: @agency, actor: @staff, booking:).call }
    assert_match(/already been extended once/, refused.message)
  end

  test "an edit the hold can't follow is refused whole, and the old hold stays (question 15)" do
    booking = bennett_booking!
    HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call
    before = booking.reload.consuming_allocations.map(&:id).sort

    rivals = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @alpha.trips.fetch("BK-105")).call.record
    guests = [ "Guest 1", "Guest 2" ].map { |label| SaveBookingTraveler.new(agency: @agency, actor: @staff, booking: rivals, attributes: { placeholder_label: label }).call.record }
    guests.each { |guest| select!(rivals, "Extension nights", "Nov 4 Garden Queen", [ guest ]) }
    HoldBookingSpace.new(agency: @agency, actor: @staff, booking: rivals).call

    refused = assert_raises(AgencyCommand::Error) { select!(booking, "Extension nights", "Nov 4 Garden Queen", [ traveler_row(booking, "Sofia") ]) }
    assert_match(/no Nov 4 Garden Queen space is left/, refused.message)
    assert_equal before, booking.reload.consuming_allocations.map(&:id).sort, "the old holds stay"
    assert_not booking.choice_selections.any? { |selection| selection.option.label == "Nov 4 Garden Queen" }, "the edit is refused whole"

    s01 = booking.choice_selections.find { |selection| selection.option.label == "S01" }
    RemoveChoiceSelection.new(agency: @agency, actor: @staff, booking:, selection: s01).call
    assert_equal 3, booking.reload.consuming_allocations.size, "removing the cabin releases only its hold"
    assert s01.reload.removed_at, "a selection with allocation history is kept as removed"
  end

  test "units have their own occupants and positions; two cabins can share a booking (BKG-14, question 19)" do
    booking = create_booking!
    rows = %w[Sofia Marcus Ava Milo].map { |name| add_traveler!(booking, name) }
    select!(booking, "Cabin", "V01", rows.first(2))
    select!(booking, "Cabin", "I01", rows.last(2))
    units = booking.reload.choice_selections.select { |selection| selection.option.choice.name == "Cabin" }
    assert_equal [ 1, 2 ], units.map(&:unit_number)
    ava = booking.price_lines.find { |line| line.booking_traveler_id == rows[2].id }
    assert_equal [ "guest_1", 258_500 ], [ ava.occupancy_position, ava.amount_minor_units ], "Ava is the 1st guest of cabin 2"

    clash = assert_raises(AgencyCommand::Error) { select!(booking, "Cabin", "O01", [ rows.first ]) }
    assert_match(/Sofia Bennett is already in another unit of Cabin/, clash.message)
    crowded = create_booking!
    four = %w[Sofia Marcus Ava Milo].map { |name| add_traveler!(crowded, name) }
    over = assert_raises(AgencyCommand::Error) { select!(crowded, "Cabin", "V01", four) }
    assert_match(/holds 3; 4 travelers would use positions/, over.message)
    DiscardClientBooking.new(agency: @agency, actor: @staff, booking: crowded).call

    HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call
    shells = booking.reload.inventory_allocations.map { |allocation| allocation.unit_shell.label }.sort
    assert_equal [ "I01-01", "V01-01" ], shells
  end

  test "a required-adult rule refuses a child-only unit at hold and lists it for confirmation (INV-09, question 21)" do
    cabin_group = @alpha.arrangements.fetch(:cruise).inventory_groups.find_by!(label: "I01")
    SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @alpha.arrangements.fetch(:cruise), group: cabin_group,
      attributes: { required_adults_per_unit: "1" }, lock_version: cabin_group.lock_version).call
    booking = create_booking!
    ava = add_traveler!(booking, "Ava")
    select!(booking, "Cabin", "I01", [ ava ])
    refused = assert_raises(AgencyCommand::Error) { HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call }
    assert_match(/Cabin 1: I01 needs 1 adult; it has 0/, refused.message)
    assert_includes BookingConfirmationCheck.new(booking.reload).blockers.map(&:message), "Cabin 1: I01 needs 1 adult; it has 0."
  end

  test "confirmation is refused and lists what is missing, each with where to fix it (BKG-45, CLT-15, D16)" do
    booking = create_booking!
    SaveBookingTraveler.new(agency: @agency, actor: @staff, booking:, attributes: { placeholder_label: "Guest 2" }).call
    refused = assert_raises(ConfirmClientBooking::Blocked) { ConfirmClientBooking.new(agency: @agency, actor: @staff, booking:).call }
    messages = refused.blockers.to_h { |blocker| [ blocker.message, blocker.anchor ] }
    assert_equal "acceptance", messages.fetch("Record the client's acceptance of the current price and terms.")
    assert_equal "booking-traveler-#{booking.booking_travelers.sole.id}", messages.fetch("Replace Guest 2 with a traveler who has a legal name and date of birth.")
    cabin = @alpha.offering.choices.find_by!(name: "Cabin")
    assert_equal "choice-#{cabin.id}", messages.fetch("Choose cabin.")
  end

  test "a discarded booking releases its holds at once, with no charge (BKG-06)" do
    booking = bennett_booking!
    HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call
    DiscardClientBooking.new(agency: @agency, actor: @staff, booking:).call
    assert booking.reload.status_discarded?
    assert booking.inventory_allocations.all?(&:state_released?)
    assert_raises(AgencyCommand::Error) { HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call }
  end

  private

  def create_booking!(trip = @trip)
    CreateClientBooking.new(agency: @agency, actor: @staff, trip:).call.record
  end

  def add_traveler!(booking, name)
    traveler = @agency.travelers.find_by!(given_names: name)
    age = traveler.age_on(AlphaFixture::STARTS_ON)
    type = age < 5 ? @types.fetch("Child 0–4") : (age < 18 ? @types.fetch("Child") : @types.fetch("Adult"))
    SaveBookingTraveler.new(agency: @agency, actor: @staff, booking:, attributes: { traveler_id: traveler.id, traveler_type_id: type.id }).call.record
  end

  def select!(booking, choice, label, rows)
    option = @alpha.offering.choices.find_by!(name: choice).options.find_by!(label:)
    SaveChoiceSelection.new(agency: @agency, actor: @staff, booking:, attributes: { offering_option_id: option.id, occupant_ids: rows.map(&:id) }).call.record
  end

  def bennett_booking!
    booking = create_booking!
    rows = %w[Sofia Marcus Ava Milo].map { |name| add_traveler!(booking, name) }
    select!(booking, "Cabin", "S01", rows)
    select!(booking, "Nov 5 hotel room", "Harbor Double", rows)
    [ 2, 3, 4 ].each { |day| select!(booking, "Extension nights", "Nov #{day} Harbor Double", rows) }
    select!(booking, "Private Miami tour", "Private Miami tour, Nov 5", rows)
    booking.reload
  end

  def traveler_row(booking, name) = booking.booking_travelers.reload.find { |row| row.traveler.given_names == name }

  def cabin_total(booking) = booking.price_lines.select { |line| line.choice_selection.option.choice.name == "Cabin" }.sum(&:amount_minor_units)
end
