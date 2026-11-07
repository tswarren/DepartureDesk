require "test_helper"

# Database guards for the step 6b records: INV-18 and D-88 (allocations move
# forward only and are never deleted), BKG-05 and BKG-14 (a booking buys its
# trip's Departure's offering, and its options), CLT-15, INV-09.
class BookingConstraintsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @booking = @alpha.bookings.fetch("BK-104")
    @allocation = @booking.inventory_allocations.first
  end

  test "an allocation moves only forward, changes nothing else, and is never deleted" do
    refuse { InventoryAllocation.where(id: @allocation.id).update_all(quantity: 9) }
    refuse { InventoryAllocation.where(id: @allocation.id).delete_all }
    InventoryAllocation.where(id: @allocation.id).update_all(state: "reserved", reserved_at: Clock.current.now, hold_expires_at: nil)
    refuse { InventoryAllocation.where(id: @allocation.id).update_all(state: "held", reserved_at: nil, hold_expires_at: Clock.current.now) }
    InventoryAllocation.where(id: @allocation.id).update_all(state: "released", released_at: Clock.current.now)
    refuse { InventoryAllocation.where(id: @allocation.id).update_all(released_at: Clock.current.now + 1) }
  end

  test "a booking buys its trip's Departure's offering, and its reference never changes" do
    other = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Elsewhere", operating_currency: "USD" }).call.record
    offering = SaveOffering.new(agency: @agency, actor: @admin, departure: other, attributes: { name: "Elsewhere package" }).call.record
    refuse do
      ClientBooking.insert_all!([ { agency_id: @agency.id, client_trip_id: @booking.client_trip_id, offering_id: offering.id, sequence: 9,
                                    booking_reference: "#{@booking.client_trip.trip_reference}-9", created_by_id: @admin.id } ])
    end
    refuse { ClientBooking.where(id: @booking.id).update_all(booking_reference: "T-99999-1") }
  end

  test "a booking traveler is a traveler or a placeholder, and a group's required adults fit its units" do
    refuse { BookingTraveler.where(id: @booking.booking_travelers.first.id).update_all(placeholder_label: "Guest 9") }
    group = @alpha.arrangements.fetch(:cruise).inventory_groups.find_by!(label: "V01")
    refuse { InventoryGroup.where(id: group.id).update_all(required_adults_per_unit: 4) }
  end

  private

  def refuse(&block)
    assert_raises(ActiveRecord::StatementInvalid) { ActiveRecord::Base.transaction(requires_new: true, &block) }
  end
end
