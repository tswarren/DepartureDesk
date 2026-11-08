# Removes an option from a draft booking. Its held space is released; the
# selection is kept as removed while allocation history points at it.
class RemoveChoiceSelection < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, selection:)
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
      selection = booking.choice_selections.find(@selection.id)
      # INV-33: a supplier request is its own record; the service stays while one is open.
      if (reservation = selection.open_supplier_reservation)
        raise Error.new("#{selection.label} has a #{reservation.status_label.downcase} supplier reservation; it can't be removed.", code: :invalid_state)
      end
      lock_groups!([ selection.inventory_group ])
      now = Clock.current.now
      selection.inventory_allocations.reject(&:state_released?).each { |allocation| allocation.update!(state: "released", released_at: now) }
      selection.price_lines.delete_all(:delete_all)
      selection.occupants.delete_all(:delete_all)
      selection.inventory_allocations.any? ? selection.update!(removed_at: now) : selection.destroy!
      after_contents_change!(booking)
      audit_booking!(booking, "client_booking.selection_removed", "choice_selection_id" => selection.id, "offering_option_id" => selection.offering_option_id)
      Result.new(status: :removed, record: selection)
    end
  end
end
