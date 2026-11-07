# Discards a booking that was never confirmed: its holds are released at
# once, with no charge, refund or initiator (BKG-06, BKG-56). The
# reference is never reused (REF-03, SC-REF-06).
class DiscardClientBooking < AgencyCommand
  include BookingCommandSupport

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
