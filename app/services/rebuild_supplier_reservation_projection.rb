class RebuildSupplierReservationProjection < AgencyCommand
  include ReservationCommandSupport

  # Public repair wrapper. Nested Reservation commands must call
  # RebuildSupplierReservationProjectionAlreadyLocked instead.
  def initialize(agency:, actor:, reservation:)
    @agency = agency
    @actor = actor
    @reservation = reservation
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      projection = RebuildSupplierReservationProjectionAlreadyLocked.new(
        agency: @agency,
        reservation: reservation
      ).call
      Result.new(status: :updated, record: projection)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
