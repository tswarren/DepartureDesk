class AbandonPlannedSupplierReservation < AgencyCommand
  include ReservationCommandSupport

  def initialize(agency:, actor:, reservation:, reason:, revision_lock_version:)
    @agency = agency
    @actor = actor
    @reservation = reservation
    @reason = reason
    @revision_lock_version = revision_lock_version
  end

  def call
    ensure_arrangement_actor!
    reason = normalize_reason(@reason)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      reservation = @agency.supplier_reservations.lock.find(@reservation.id)
      revision = reservation.revisions.lock.where(status: "planned").sole
      ensure_current_lock_version!(revision, @revision_lock_version)
      revision.update!(
        status: "abandoned", abandoned_at: Time.current, abandoned_reason: reason
      )
      RebuildSupplierReservationProjection.new(
        agency: @agency, actor: @actor, reservation: reservation
      ).call
      audit!(
        agency: @agency, action: "supplier_reservation.abandoned", subject: reservation, actor: @actor,
        details: {
          "supplier_reservation_id" => reservation.id,
          "supplier_reservation_revision_id" => revision.id,
          "reason" => reason
        }
      )
      Result.new(status: :updated, record: reservation)
    end
  rescue ActiveRecord::SoleRecordExceeded
    raise Error.new("That reservation does not have one planned revision.", code: :invalid_state)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
