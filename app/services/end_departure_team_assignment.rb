class EndDepartureTeamAssignment < DepartureCommand
  def initialize(agency:, departure:, assignment:, reason:, ended_on: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @assignment = assignment
    @reason = reason.to_s.strip
    @ended_on = ended_on
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?

    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        departure: @departure,
        memberships: [ @assignment.agency_membership ],
        team_assignments: [ @assignment ]
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
    require_manager_or_administrator!(actor, @departure)
    ensure_fresh_lock!(@departure, @lock_version)
    ensure_assignment_belongs_to_agency!(@agency, @assignment)
    unless @assignment.departure_id == @departure.id
      raise Error.new("That assignment is not part of this departure.", code: :invalid)
    end
    unless @assignment.current?
      raise Error.new("That assignment has already ended.", code: :invalid_state)
    end
    if @assignment.group_manager?
      raise Error.new("Replace the group manager instead of ending the only current manager.", code: :invalid_state)
    end

    ended_on = @ended_on.presence || OfficeDate.today(@departure.office)
    @assignment.end!(ended_by: actor, reason: @reason, ended_on:)
    audit!(
      agency: @agency,
      action: "departure.team_assignment_ended",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "assignment_id" => @assignment.id,
        "assignment_role" => @assignment.assignment_role,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure, assignment: @assignment)
  end
end
