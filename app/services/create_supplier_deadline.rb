class CreateSupplierDeadline < DepartureCommand
  def initialize(agency:, deposit_requirement: nil, clause: nil, name: nil, due_on: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @deposit = deposit_requirement
    @clause = clause
    @source = @deposit || @clause
    @departure = @source&.departure
    @name = name || @source&.name
    @due_on = due_on || default_due_on
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("Choose exactly one supplier deadline source.", code: :invalid) unless [ @deposit.present?, @clause.present? ].one?
    raise Error.new("A due date is required.", code: :invalid) if @due_on.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @source.office ],
        departure: @departure,
        supplier_arrangements: [ @source.arrangement ],
        supplier_deposit_requirements: [ @deposit ],
        supplier_clauses: [ @clause ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier deadline source was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @source.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@source, @lock_version)
    raise Error.new("Deadlines can only be created for active deposit requirements.", code: :invalid_state) if @deposit && !@deposit.active?

    deadline = @source.supplier_deadlines.create!(
      agency: @agency,
      office: @source.office,
      departure: @departure,
      arrangement: @source.arrangement,
      name: @name,
      original_due_on: @due_on,
      due_on: @due_on,
      status: "open",
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_deadline.created", subject: deadline, details: { "supplier_deadline_id" => deadline.id, "source_deposit_requirement_id" => @deposit&.id, "source_clause_id" => @clause&.id, "due_on" => deadline.due_on }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_deadline: deadline)
  end

  def default_due_on
    return @deposit.due_on if @deposit

    @clause&.deadline_due_on || @clause&.trigger_on
  end
end
