class AssignDepartureTeamMember < DepartureCommand
  def initialize(agency:, departure:, membership:, role:, effective_from: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @membership = membership
    @role = role.to_s
    @effective_from = effective_from
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        departure: @departure,
        memberships: [ @membership ]
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
    unless @departure.nonterminal?
      raise Error.new("Team assignments can only be added to a draft or planning departure.", code: :invalid_state)
    end
    unless DepartureTeamAssignment::ROLES.include?(@role)
      raise Error.new("That team role is not valid.", code: :invalid)
    end
    ensure_eligible_team_member!(@membership, @departure.office)

    if @departure.team_assignments.current.exists?(assignment_role: @role)
      raise Error.new("Replace the current assignment instead of creating a second one.", code: :conflict)
    end

    assignment = @departure.team_assignments.create!(
      agency: @agency,
      agency_membership: @membership,
      membership_status: "active",
      assignment_role: @role,
      member_name_snapshot: @membership.agency_display_name,
      effective_from: @effective_from.presence || OfficeDate.today(@departure.office),
      assigned_at: Time.current,
      assigned_by_membership: actor
    )
    audit!(
      agency: @agency,
      action: "departure.team_member_assigned",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "assignment_id" => assignment.id,
        "assignment_role" => assignment.assignment_role,
        "agency_membership_id" => @membership.id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, departure: @departure, assignment:)
  end
end
