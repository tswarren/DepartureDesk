class ReparentSupplierArrangement < DepartureCommand
  def initialize(agency:, arrangement:, parent_arrangement:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @arrangement = arrangement
    @parent_arrangement = parent_arrangement
    @departure = arrangement.departure
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      ancestry = ancestry_for(@parent_arrangement)
      with_departure_locks(@agency, offices: [ @arrangement.office ], departure: @departure, supplier_arrangements: [ @arrangement, @parent_arrangement, *ancestry ]) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This supplier arrangement was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  rescue ActiveRecord::StatementInvalid
    raise Error.new("That parent arrangement would create a cycle.", code: :cycle)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @arrangement.office)
    require_manager_or_administrator!(actor, @departure)
    ensure_fresh_lock!(@arrangement, @lock_version)
    raise Error.new("Cancelled supplier arrangements cannot be reparented.", code: :invalid_state) if @arrangement.cancelled?
    if @parent_arrangement && (@parent_arrangement.departure_id != @departure.id || @parent_arrangement.cancelled?)
      raise Error.new("Choose a nonterminal parent arrangement on this departure.", code: :invalid)
    end

    previous_parent_id = @arrangement.parent_arrangement_id
    @arrangement.update!(parent_arrangement: @parent_arrangement)
    audit!(agency: @agency, action: "supplier_arrangement.reparented", subject: @arrangement, details: { "supplier_arrangement_id" => @arrangement.id, "from_parent_arrangement_id" => previous_parent_id, "to_parent_arrangement_id" => @arrangement.parent_arrangement_id }, **actor_audit_args)
    CommandResult.new(status: :accepted, departure: @departure, supplier_arrangement: @arrangement)
  end

  def ancestry_for(arrangement)
    list = []
    current = arrangement
    while current
      list << current
      current = current.parent_arrangement
    end
    list
  end
end
