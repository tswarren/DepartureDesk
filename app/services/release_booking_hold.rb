# Releases a draft booking's held space, all of it or one selection's, so
# an edit the hold can't follow can be saved (step 6 plan, question 15).
# Capacity returns at once (INV-24).
class ReleaseBookingHold < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, selection: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @selection = selection
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      booking = lock_booking!
      ensure_draft!(booking)
      held = booking.inventory_allocations.select(&:state_held?)
      held = held.select { |allocation| allocation.choice_selection_id == @selection.id } if @selection
      raise Error.new("There is no held space to release.", code: :invalid_state) if held.empty?

      lock_groups!(held.map(&:inventory_group))
      now = Clock.current.now
      held.each { |allocation| allocation.update!(state: "released", released_at: now) }
      audit_booking!(booking, "client_booking.hold_released", "inventory_allocation_ids" => held.map(&:id))
      Result.new(status: :updated, record: booking)
    end
  end
end
