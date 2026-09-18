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
      _booking_supplier, _departure, _arrangement, _version, reservation, revision =
        lock_reservation_mutation_graph!(@reservation, revision_status: "planned")
      raise Error.new("That reservation does not have one planned revision.", code: :invalid_state) if revision.nil?

      ensure_current_lock_version!(revision, @revision_lock_version)
      revision.update!(
        status: "abandoned", abandoned_at: Time.current, abandoned_reason: reason
      )
      rebuild_reservation_projection_already_locked!(reservation)
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
