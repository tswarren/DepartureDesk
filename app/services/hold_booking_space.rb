# Hold space (BKG-11, INV-20): takes every inventory-linked service the
# booking has chosen, all or none, naming any that can't be held.
# On-request and rate-only services take nothing and don't block. The hold
# lasts the Departure's hold duration and expires at 11:59 p.m. agency
# time on its last day (BKG-09, SET-10). Lapsed holds are released first
# (BKG-10). Staff may pick a whole unit's shell.
class HoldBookingSpace < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, shell_choices: {})
    @agency = agency
    @actor = actor
    @booking = booking
    @shell_choices = shell_choices.to_h.transform_keys(&:to_s).compact_blank
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      ensure_on_sale!(@departure, "space can't be held")
      raise Error.new("Add the travelers before holding space.", code: :invalid) if booking.booking_travelers.empty?
      problems = occupancy_problems(booking)
      raise Error.new("Space can't be held: #{problems.join(" ")}", code: :invalid) if problems.any?

      lapsed = booking.inventory_allocations.select(&:lapsed?)
      lock_groups!(lapsed.map(&:inventory_group))
      lapsed.each { |allocation| allocation.update!(state: "released", released_at: Clock.current.now) }
      active = booking.consuming_allocations
      held = active.map { |allocation| allocation_signature(allocation) }
      needs = allocation_needs(booking).reject { |need| held.include?(need_signature(need)) }
      raise Error.new("Nothing in this booking needs space held.", code: :invalid_state) if needs.empty?

      expires_at = active.select(&:state_held?).map(&:hold_expires_at).min || hold_expiry(@departure)
      allocations = allocate!(booking, needs, expires_at:, extended_at: active.filter_map(&:hold_extended_at).min, shell_choices: @shell_choices)
      audit_booking!(booking, "client_booking.space_held",
        "inventory_allocation_ids" => allocations.map(&:id), "hold_expires_at" => expires_at.iso8601)
      Result.new(status: :created, record: booking)
    end
  end
end
