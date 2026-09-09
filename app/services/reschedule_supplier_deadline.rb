class RescheduleSupplierDeadline < DepartureCommand
  def initialize(agency:, deadline:, due_on:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @deadline = deadline
    @departure = deadline.departure
    @due_on = due_on
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reschedule reason is required.", code: :invalid) if @reason.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @deadline.office ], departure: @departure, supplier_arrangements: [ @deadline.arrangement ], supplier_deadlines: [ @deadline ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier deadline was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @deadline.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@deadline, @lock_version)
    raise Error.new("Only open supplier deadlines can be rescheduled.", code: :invalid_state) unless @deadline.open?

    previous_due_on = @deadline.due_on
    @deadline.update!(due_on: @due_on, rescheduled_at: Time.current, rescheduled_by_membership: actor, reschedule_reason: @reason)
    audit!(agency: @agency, action: "supplier_deadline.rescheduled", subject: @deadline, details: { "supplier_deadline_id" => @deadline.id, "previous_due_on" => previous_due_on, "due_on" => @deadline.due_on, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_deadline: @deadline)
  end
end
