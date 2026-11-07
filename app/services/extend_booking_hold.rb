# Extends a booking's hold once, by the hold duration, recording the new
# expiry (BKG-09). The one extension carries across replaced allocations
# (step 6 plan, question 20).
class ExtendBookingHold < AgencyCommand
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
      held = booking.consuming_allocations.select(&:state_held?)
      raise Error.new("There is no active hold to extend.", code: :invalid_state) if held.empty?
      raise Error.new("This hold has already been extended once.", code: :invalid_state) if held.any? { |allocation| extended_in_chain?(allocation) }

      lock_groups!(held.map(&:inventory_group))
      zone = @agency.default_timezone
      expires_at = AgencyLocalTime.end_of_date(held.map(&:hold_expires_at).min.in_time_zone(zone).to_date + @departure.effective_hold_duration_days, zone)
      now = Clock.current.now
      held.each { |allocation| allocation.update!(hold_expires_at: expires_at, hold_extended_at: now) }
      audit_booking!(booking, "client_booking.hold_extended", "hold_expires_at" => expires_at.iso8601)
      Result.new(status: :updated, record: booking)
    end
  end

  private

  def extended_in_chain?(allocation)
    seen = 0
    while allocation && seen < 100
      return true if allocation.hold_extended_at.present?

      allocation = allocation.replaces
      seen += 1
    end
    false
  end
end
