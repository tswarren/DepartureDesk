require "test_helper"

# Regression tests for the review after step 6: confirming or extending past
# a scheduled reduction (INV-23, D-88), shells added with a later effective
# date (D-88), option changes under accepted bookings (BKG-39), and the name
# as booked on confirmed bookings (CLT-13).
class BookingReviewFixesTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @agency.update_columns(default_timezone: AlphaFixture::TIME_ZONE)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @hotel = @alpha.arrangements.fetch(:hotel)
    @cruise = @alpha.arrangements.fetch(:cruise)
  end

  test "confirming or extending a hold can't exceed a reduction scheduled after its expiry" do
    nov4 = @hotel.inventory_groups.find_by!(label: "Nov 4 Garden Queen")
    CorrectCapacity.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @hotel, group: nov4, direction: "down", quantity: 1,
      corrects_event_id: nov4.capacity_events.find_by!(event_type: "established").id, effective_on: Date.new(2027, 1, 14),
      evidence_note: "Hotel count corrected.").call
    rowan = @alpha.bookings.fetch("BK-101")

    refused = assert_raises(AgencyCommand::Error) { ExtendBookingHold.new(agency: @agency, actor: @staff, booking: rowan).call }
    assert_match(/Nov 4 Garden Queen has a supply reduction scheduled before the new expiry/, refused.message)

    accept!(rowan, "Nadia Rowan")
    blocked = assert_raises(ConfirmClientBooking::Blocked) { ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: rowan.reload).call }
    assert_includes blocked.blockers.map(&:message), "Nov 4 Garden Queen has a supply reduction scheduled that confirming this booking would exceed; resolve it before confirming."
    assert rowan.reload.status_draft?
  end

  test "a shell added with a later effective date can't be held before then" do
    i01 = @cruise.inventory_groups.find_by!(label: "I01")
    i01.unit_shells.each do |shell|
      RecordSupplierRelease.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @cruise, group: i01, unit_shell_id: shell.id,
        evidence_note: "Alpha took the cabin back.").call
    end
    IncreaseCapacity.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @cruise, group: i01.reload, quantity: 1,
      effective_on: Date.new(2027, 2, 1), evidence_note: "One I01 cabin from Feb 1.").call

    booking = CreateClientBooking.new(agency: @agency, actor: @staff, trip: @alpha.trips.fetch("BK-104")).call.record
    guest = SaveBookingTraveler.new(agency: @agency, actor: @staff, booking:, attributes: { placeholder_label: "Guest 1" }).call.record
    option = @alpha.offering.choices.find_by!(name: "Cabin").options.find_by!(label: "I01")
    SaveChoiceSelection.new(agency: @agency, actor: @staff, booking:, attributes: { offering_option_id: option.id, occupant_ids: [ guest.id ] }).call
    refused = assert_raises(AgencyCommand::Error) { HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call }
    assert_match(/no I01 space is left for the length of the hold/, refused.message)

    set_clock Time.utc(2027, 2, 2, 15)
    HoldBookingSpace.new(agency: @agency, actor: @staff, booking:).call
    assert_equal :held, booking.reload.hold_state.first
  end

  test "an option bookings use can't change its group or be removed, and a group change would make acceptance stale" do
    room = @alpha.offering.choices.find_by!(name: "Nov 5 hotel room")
    option = room.options.find_by!(label: "Garden Queen")
    nov1 = @hotel.inventory_groups.find_by!(label: "Nov 1 Garden Queen")
    option.prices.each { |price| RemoveOfferingPrice.new(agency: @agency, actor: @admin, departure: @alpha.departure, offering: @alpha.offering, price:).call }
    refused = assert_raises(AgencyCommand::Error) do
      SaveOfferingOption.new(agency: @agency, actor: @admin, departure: @alpha.departure, offering: @alpha.offering, choice: room, option:,
        attributes: { inventory_group_id: nov1.id }, lock_version: option.reload.lock_version).call
    end
    assert_match(/Bookings use this option/, refused.message)
    assert_match(/Bookings use Garden Queen/, assert_raises(AgencyCommand::Error) { RemoveOfferingOption.new(agency: @agency, actor: @admin, departure: @alpha.departure, offering: @alpha.offering, option:).call }.message)
    assert_match(/Bookings use Nov 5 hotel room/, assert_raises(AgencyCommand::Error) { RemoveOfferingChoice.new(agency: @agency, actor: @admin, departure: @alpha.departure, offering: @alpha.offering, choice: room).call }.message)

    rowan = @alpha.bookings.fetch("BK-101")
    acceptance = accept!(rowan, "Nadia Rowan")
    OfferingOption.where(id: option.id).update_all(inventory_group_id: nov1.id)
    assert_not acceptance.covers?(rowan.reload), "the fingerprint includes the inventory each option draws on"
  end

  test "a confirmed booking shows the name as booked, not later profile edits (CLT-13)" do
    rowan = @alpha.bookings.fetch("BK-101")
    accept!(rowan, "Nadia Rowan")
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: rowan.reload).call
    nadia = @agency.travelers.find_by!(given_names: "Nadia")
    SaveTraveler.new(agency: @agency, actor: @staff, traveler: nadia, attributes: { surname: "Changed" }, lock_version: nadia.lock_version).call
    row = rowan.reload.booking_travelers.find { |candidate| candidate.traveler_id == nadia.id }
    assert_equal "Nadia Rowan", row.display_name
  end

  private

  def accept!(booking, name)
    RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking:, attributes: { accepted_by: name, acceptance_method: "phone", note: "Accepted by phone." }).call.record
  end
end
