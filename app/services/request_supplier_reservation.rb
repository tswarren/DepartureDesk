# Starts a supplier request for a booking's units from one arrangement
# (INV-33): only when staff explicitly start it, at the scope the
# arrangement defines (SUP-10). Under arrangement scope one request may
# cover several units; under per-unit scope exactly one; under none, no
# request. Each unit needs one (step 7 plan, question 3) and has at most one
# open request. Creating it is local tracking: nothing is sent, and the
# booking, its prices and its allocations are unchanged.
class RequestSupplierReservation < AgencyCommand
  include SupplierReservationSupport

  def initialize(agency:, actor:, booking:, arrangement:, selection_ids:)
    @agency = agency
    @actor = actor
    @booking = booking
    @arrangement = arrangement
    @selection_ids = Array(selection_ids).compact_blank.uniq
  end

  def call
    ensure_reservation_actor!
    raise Error.new("Choose at least one service to request.", code: :invalid) if @selection_ids.empty?

    ActiveRecord::Base.transaction do
      _departure, booking, arrangement = lock_reservation_context!(@booking, @arrangement)
      raise Error.new("#{arrangement.supplier.display_name_for_directory} doesn't track supplier reservations on this arrangement.", code: :invalid_state) if arrangement.reservations_none?
      raise Error.new("A #{booking.status} booking can't start a supplier request.", code: :invalid_state) unless booking.status_draft? || booking.status_confirmed?

      selections = booking.choice_selections.includes(:supplier_reservation_units, option: [ :choice, { inventory_group: :supplier_arrangement } ])
        .select { |selection| @selection_ids.include?(selection.id) }
      raise Error.new("Each service must be on this booking.", code: :invalid) if selections.size != @selection_ids.size

      check_units!(selections, arrangement)
      reservation = arrangement.supplier_reservations.create!(agency: @agency, client_booking: booking, status: "requested",
        requested_by: @actor, requested_at: Clock.current.now)
      selections.each { |selection| reservation.units.create!(agency: @agency, choice_selection: selection, open: true, created_at: Clock.current.now) }
      record_event!(reservation, "requested", agency_today)
      audit!(agency: @agency, action: "supplier_reservation.requested", subject: reservation, actor: @actor,
        details: { "supplier_reservation_id" => reservation.id, "client_booking_id" => booking.id, "supplier_arrangement_id" => arrangement.id,
                   "choice_selection_ids" => selections.map(&:id) })
      Result.new(status: :created, record: reservation)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("A service already has an open supplier request.", code: :conflict)
  end

  private

  def check_units!(selections, arrangement)
    selections.each do |selection|
      if selection.inventory_group.supplier_arrangement_id != arrangement.id
        raise Error.new("#{selection.label} isn't from #{arrangement.supplier.display_name_for_directory}.", code: :invalid)
      end
      raise Error.new("#{selection.label} is in the group block and needs no separate request.", code: :invalid) unless selection.needs_supplier_request?
      raise Error.new("#{selection.label} already has an open supplier request.", code: :conflict) if selection.open_supplier_reservation
    end
    return unless arrangement.reservations_per_unit? && selections.size > 1

    raise Error.new("This arrangement tracks a reservation for each unit; request one service at a time.", code: :invalid)
  end
end
