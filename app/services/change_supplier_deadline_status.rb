class ChangeSupplierDeadlineStatus < DepartureCommand
  ACTIONS = {
    "completed" => "supplier_deadline.completed",
    "waived" => "supplier_deadline.waived",
    "cancelled" => "supplier_deadline.cancelled"
  }.freeze

  def initialize(agency:, deadline:, status:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @deadline = deadline
    @departure = deadline.departure
    @status = status.to_s
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A status reason is required.", code: :invalid) if @reason.blank?
    raise Error.new("Choose a supported deadline status.", code: :invalid) unless ACTIONS.key?(@status)
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
    ensure_fresh_lock!(@deadline, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_deadline: @deadline) if @deadline.status == @status
    raise Error.new("Only open supplier deadlines can change status.", code: :invalid_state) unless @deadline.open?

    @deadline.update!(status: @status, status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: ACTIONS.fetch(@status), subject: @deadline, details: { "supplier_deadline_id" => @deadline.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_deadline: @deadline)
  end
end
