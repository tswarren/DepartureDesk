class SetPrimaryDeparturePartyRole < DepartureCommand
  def initialize(agency:, departure:, assignment:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @assignment = assignment
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    current = @departure.party_role_assignments.current.where(role: @assignment.role).to_a
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        departure: @departure,
        parties: current.map(&:party),
        party_role_assignments: current
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This departure was updated by someone else.", code: :conflict)
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @departure.office)
    ensure_fresh_lock!(@departure, @lock_version)
    unless @assignment.departure_id == @departure.id && @assignment.current?
      raise Error.new("Choose a current assignment on this departure.", code: :invalid)
    end
    return CommandResult.new(status: :accepted, departure: @departure, assignment: @assignment) if @assignment.is_primary?

    @departure.party_role_assignments.current.where(role: @assignment.role, is_primary: true).find_each do |current_primary|
      current_primary.update!(is_primary: false)
    end
    @assignment.update!(is_primary: true)
    audit!(
      agency: @agency,
      action: "departure.party_role_primary_changed",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "assignment_id" => @assignment.id,
        "role" => @assignment.role
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure, assignment: @assignment)
  end
end
