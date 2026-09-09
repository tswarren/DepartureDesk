class UpdateSupplierReservation < DepartureCommand
  EDITABLE = %w[name operational_notes status].freeze

  def initialize(agency:, reservation:, name:, operational_notes: nil, status: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @reservation = reservation
    @departure = reservation.departure
    @status = status.to_s.presence
    @name = name
    @operational_notes = operational_notes
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @reservation.office ], departure: @departure, supplier_arrangements: [ @reservation.arrangement ], supplier_reservations: [ @reservation ]) { perform }
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
    raise Error.new("Terminal reservations cannot be updated.", code: :invalid_state) unless @reservation.nonterminal?

    before = snapshot
    @reservation.assign_attributes(name: @name, operational_notes: @operational_notes)
    apply_status!(actor) if @status
    return CommandResult.new(status: :accepted, departure: @departure, supplier_reservation: @reservation) unless @reservation.changed?

    @reservation.save!
    after = snapshot
    changed = EDITABLE.select { |field| before[field] != after[field] }
    action = changed.include?("status") && @reservation.submitted? ? "supplier_reservation.submitted" : "supplier_reservation.updated"
    audit!(agency: @agency, action:, subject: @reservation, details: { "supplier_reservation_id" => @reservation.id, "changed_fields" => changed, "before" => before.slice(*changed), "after" => after.slice(*changed) }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_reservation: @reservation)
  end

  def apply_status!(actor)
    return if @status == @reservation.status
    unless @reservation.requested? && @status == "submitted"
      raise Error.new("That reservation status transition is not allowed here.", code: :invalid_state)
    end

    @reservation.status = "submitted"
    @reservation.status_changed_at = Time.current
    @reservation.status_changed_by_membership = actor
  end

  def snapshot
    { "name" => @reservation.name, "operational_notes" => @reservation.operational_notes, "status" => @reservation.status }
  end
end
