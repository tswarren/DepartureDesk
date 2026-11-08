# Shared steps for supplier reservation commands (INV-33 to INV-37). They
# need Supplier arrangements (step 7 plan, question 7) and lock agency,
# Departure, booking, then the arrangement, the order allocation commands
# use (step 6 plan, question 16). Nothing here touches capacity.
module SupplierReservationSupport
  STALE_MESSAGE = "This record changed. Reload it and try again."

  private

  def agency_today = Clock.current.today_in(@agency.default_timezone)

  def ensure_reservation_actor!
    ensure_directory_actor!(@actor, @agency, :manage_supplier_reservations)
    ensure_active_agency!(@agency)
  end

  def lock_reservation_context!(booking, arrangement)
    @agency.lock!
    trip = @agency.client_trips.find(booking.client_trip_id)
    departure = @agency.departures.lock.find(trip.departure_id)
    locked_booking = @agency.client_bookings.lock.find(booking.id)
    locked_arrangement = departure.supplier_arrangements.lock.find_by(id: arrangement.id) or
      raise AgencyCommand::Error.new("That arrangement isn't on this booking's Departure.", code: :not_found)
    [ departure, locked_booking, locked_arrangement ]
  end

  def record_event!(reservation, event_type, occurred_on)
    reservation.events.create!(agency: @agency, event_type:, occurred_on:, recorded_by: @actor, recorded_at: Clock.current.now)
  end
end
