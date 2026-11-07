require "test_helper"

# Step 6 plan questions 17 and 18: agency reductions refused below held or
# reserved space (INV-26), a supplier release below it leaving a derived
# conflict (INV-19, INV-23), and deposits owed by every cabin not returned
# to the supplier, whatever its bookings.
class CapacityGuardsTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @agency.update_columns(default_timezone: AlphaFixture::TIME_ZONE)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @hotel = @alpha.arrangements.fetch(:hotel)
    @nov4 = @hotel.inventory_groups.find_by!(label: "Nov 4 Garden Queen")
  end

  test "a correction below held places is refused, at once or dated, but one after the hold lapses succeeds" do
    opening = @nov4.capacity_events.find_by!(event_type: "established")
    refused = assert_raises(AgencyCommand::Error) { correct_down!(1) }
    assert_match(/below what is held or reserved, by 1/, refused.message)

    ExtendBookingHold.new(agency: @agency, actor: @admin, booking: @alpha.bookings.fetch("BK-101")).call
    dated = assert_raises(AgencyCommand::Error) { correct_down!(1, effective_on: Date.new(2027, 1, 14)) }
    assert_match(/below what is held or reserved/, dated.message, "a scheduled reduction is checked while the hold is still active then")

    later = correct_down!(1, effective_on: Date.new(2027, 1, 20))
    assert later.persisted?, "BK-101's extended hold lapses on Jan 15, before the correction applies"
    assert_equal opening, later.corrects_event
  end

  test "a supplier release below held space is recorded, then blocks new holds and confirmation" do
    shell = @hotel.inventory_groups.find_by!(label: "Nov 5 Garden Queen").unit_shells.first
    booking = @alpha.bookings.fetch("BK-101")
    assert(booking.inventory_allocations.any? { |allocation| allocation.unit_shell_id == shell.id })

    RecordSupplierRelease.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @hotel, group: shell.inventory_group, unit_shell_id: shell.id,
      evidence_note: "Hotel took the room back.").call
    assert shell.reload.returned_to_supplier?
    assert GroupCapacity.new(group: shell.inventory_group.reload).conflict?
    assert_includes BookingConfirmationCheck.new(booking.reload).blockers.map(&:message),
      "The supplier reduced space below what this booking holds; resolve it before confirming."

    rival = CreateClientBooking.new(agency: @agency, actor: @admin, trip: @alpha.trips.fetch("BK-104")).call.record
    guest = SaveBookingTraveler.new(agency: @agency, actor: @admin, booking: rival, attributes: { placeholder_label: "Guest 1" }).call.record
    option = @alpha.offering.choices.find_by!(name: "Nov 5 hotel room").options.find_by!(label: "Garden Queen")
    SaveChoiceSelection.new(agency: @agency, actor: @admin, booking: rival, attributes: { offering_option_id: option.id, occupant_ids: [ guest.id ] }).call
    refused = assert_raises(AgencyCommand::Error) { HoldBookingSpace.new(agency: @agency, actor: @admin, booking: rival).call }
    assert_match(/the supplier reduced Nov 5 Garden Queen below what is held/, refused.message)
  end

  test "Agreement A's deposits post for held cabins as for free ones, on the Mar 1 date arm" do
    cruise = @alpha.arrangements.fetch(:cruise)
    held = @alpha.bookings.values.flat_map(&:inventory_allocations).filter_map(&:unit_shell).select { |shell| shell.inventory_group.supplier_arrangement_id == cruise.id }
    assert_equal 3, held.size
    assert(held.all? { |shell| shell.reload.status == "fully_allocated" })

    set_clock Time.utc(2027, 3, 1, 14)
    perform_enqueued_jobs { PostDueSupplierAmountsJob.perform_now }
    full = AmountDue.where(supplier_arrangement: cruise).where.not(unit_shell_id: nil)
    assert_equal 32, full.count, "every cabin not returned to the supplier owes its deposit"
    assert_empty held.map(&:id) - full.pluck(:unit_shell_id)
  end

  private

  def correct_down!(quantity, effective_on: nil)
    CorrectCapacity.new(agency: @agency, actor: @admin, departure: @alpha.departure, arrangement: @hotel, group: @nov4, direction: "down", quantity:,
      corrects_event_id: @nov4.capacity_events.find_by!(event_type: "established").id, effective_on:, evidence_note: "Hotel count corrected.").call.record
  end
end
