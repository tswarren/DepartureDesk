# Extends a booking's hold once, by the hold duration, recording the new
# expiry (BKG-09). The one extension carries across replaced allocations
# (step 6 plan, question 20).
class ExtendBookingHold < AgencyCommand
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
      held = booking.consuming_allocations.select(&:state_held?)
      raise Error.new("There is no active hold to extend.", code: :invalid_state) if held.empty?
      raise Error.new("This hold has already been extended once.", code: :invalid_state) if held.any? { |allocation| extended_in_chain?(allocation) }

      lock_groups!(held.map(&:inventory_group))
      zone = @agency.default_timezone
      expires_at = AgencyLocalTime.end_of_date(held.map(&:hold_expires_at).min.in_time_zone(zone).to_date + @departure.effective_hold_duration_days, zone)
      check_supply!(held, expires_at)
      now = Clock.current.now
      held.each { |allocation| allocation.update!(hold_expires_at: expires_at, hold_extended_at: now) }
      audit_booking!(booking, "client_booking.hold_extended", "hold_expires_at" => expires_at.iso8601)
      Result.new(status: :updated, record: booking)
    end
  end

  private

  # D-88: the longer hold must fit every supply point until its new expiry.
  def check_supply!(held, expires_at)
    held.group_by(&:inventory_group).each do |group, allocations|
      capacity = GroupCapacity.new(group: group.reload)
      extended = allocations.map { |allocation| GroupCapacity::Projected.from(allocation, hold_expires_at: expires_at) }
      next unless capacity.shortfall(capacity.project(changed: extended))

      raise Error.new("The hold can't be extended: #{group.label} has a supply reduction scheduled before the new expiry.", code: :invalid_state)
    end
  end

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
