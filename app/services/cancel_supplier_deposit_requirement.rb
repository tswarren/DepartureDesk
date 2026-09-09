class CancelSupplierDepositRequirement < DepartureCommand
  def initialize(agency:, deposit_requirement:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @deposit = deposit_requirement
    @departure = deposit_requirement.departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A cancellation reason is required.", code: :invalid) if @reason.blank?
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
    require_manager_or_administrator!(actor, @departure)
    ensure_fresh_lock!(@deposit, @lock_version)
    return CommandResult.new(status: :accepted, departure: @departure, supplier_deposit_requirement: @deposit) if @deposit.cancelled?

    @deposit.update!(status: "cancelled", status_reason: @reason, status_changed_at: Time.current, status_changed_by_membership: actor)
    audit!(agency: @agency, action: "supplier_deposit_requirement.cancelled", subject: @deposit, details: { "supplier_deposit_requirement_id" => @deposit.id, "reason" => @reason }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_deposit_requirement: @deposit)
  end
end
