# Discards a booking that was never confirmed: its holds are released at
# once, with no charge, refund or initiator (BKG-06, BKG-56). The
# reference is never reused (REF-03, SC-REF-06). A reseller discards only
# while the booking's hold is active (BKG-56, ACC-15).
class DiscardClientBooking < AgencyCommand
  include BookingCommandSupport
  allow_reseller_actor

  def initialize(agency:, actor:, booking:)
    @agency = agency
    @actor = actor
    @booking = booking
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      if reseller_actor? && booking.hold_state.first != :held
        raise Error.new("A reseller discards a booking only while its hold is active. Ask the agency to discard it.", code: :invalid_state)
      end
      held = booking.inventory_allocations.select(&:state_held?)
      lock_groups!(held.map(&:inventory_group))
      now = Clock.current.now
      held.each { |allocation| allocation.update!(state: "released", released_at: now) }
      booking.update!(status: "discarded", discarded_at: now)
      audit_booking!(booking, "client_booking.discarded", "released_allocation_ids" => held.map(&:id))
      Result.new(status: :updated, record: booking)
    end
  end
end
