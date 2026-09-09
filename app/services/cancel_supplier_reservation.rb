class CancelSupplierReservation < DepartureCommand
  def initialize(agency:, reservation:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @reservation = reservation
    @departure = reservation.departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A cancellation reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @reservation.office ], departure: @departure, supplier_reservations: [ @reservation ]) { perform }
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
    ensure_fresh_lock!(@reservation, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_reservation: @reservation) if @reservation.cancelled?
    raise Error.new("Only nonterminal reservations can be cancelled.", code: :invalid_state) unless @reservation.nonterminal?

    @reservation.update!(status: "cancelled", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_reservation.cancelled", subject: @reservation, details: { "supplier_reservation_id" => @reservation.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_reservation: @reservation)
  end
end
