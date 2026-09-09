class CreateSupplierDeadline < DepartureCommand
  def initialize(agency:, deposit_requirement:, name: nil, due_on: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @deposit = deposit_requirement
    @departure = deposit_requirement.departure
    @name = name || deposit_requirement.name
    @due_on = due_on || deposit_requirement.due_on
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A due date is required.", code: :invalid) if @due_on.blank?
    ActiveRecord::Base.transaction do
      with_departure_locks(@agency, offices: [ @deposit.office ], departure: @departure, supplier_arrangements: [ @deposit.arrangement ], supplier_deposit_requirements: [ @deposit ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier deposit requirement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @deposit.office)
    ensure_departure_can_receive_supplier_planning!(@departure)
    ensure_fresh_lock!(@deposit, @lock_version)
    raise Error.new("Deadlines can only be created for active deposit requirements.", code: :invalid_state) unless @deposit.active?

    deadline = @deposit.supplier_deadlines.create!(
      agency: @agency,
      office: @deposit.office,
      departure: @departure,
      arrangement: @deposit.arrangement,
      name: @name,
      original_due_on: @due_on,
      due_on: @due_on,
      status: "open",
      created_by_membership: actor,
      status_changed_at: Time.current,
      status_changed_by_membership: actor
    )
    audit!(agency: @agency, action: "supplier_deadline.created", subject: deadline, details: { "supplier_deadline_id" => deadline.id, "source_deposit_requirement_id" => @deposit.id, "due_on" => deadline.due_on }, **actor_audit_args)
    CommandResult.new(status: :created, departure: @departure, supplier_deadline: deadline)
  end
end
