class ConfirmSupplierReservation < DepartureCommand
  def initialize(agency:, reservation:, without_identifier_reason: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @reservation = reservation
    @departure = reservation.departure
    @without_identifier_reason = without_identifier_reason.to_s.strip.presence
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    confirmations = @reservation.supplier_confirmations.effective.to_a
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @reservation.office ], departure: @departure, supplier_reservations: [ @reservation ], supplier_confirmations: confirmations) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier reservation was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @reservation.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@reservation, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_reservation: @reservation) if @reservation.confirmed?
    unless @reservation.requested? || @reservation.submitted?
      raise Error.new("Only requested or submitted reservations can be confirmed.", code: :invalid_state)
    end

    has_confirmation = @reservation.supplier_confirmations.effective.exists?
    unless has_confirmation || @without_identifier_reason.present?
      raise Error.new("Record a confirmation identifier or explain why the supplier confirmed without one.", code: :confirmation_evidence_required)
    end

    attrs = { status: "confirmed", status_changed_at: Time.current, status_changed_by_membership: actor }
    if @without_identifier_reason.present?
      attrs.merge!(confirmed_without_identifier_reason: @without_identifier_reason, confirmed_without_identifier_at: Time.current, confirmed_without_identifier_by_membership: actor)
    end
    @reservation.update!(attrs)
    audit!(agency: @agency, action: "supplier_reservation.confirmed", subject: @reservation, details: { "supplier_reservation_id" => @reservation.id, "confirmation_ids" => @reservation.supplier_confirmations.effective.pluck(:id), "without_identifier_reason" => @without_identifier_reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_reservation: @reservation)
  end
end
