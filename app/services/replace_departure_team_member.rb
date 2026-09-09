class ReplaceDepartureTeamMember < DepartureCommand
  def initialize(agency:, departure:, role:, membership:, reason:, effective_from: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @role = role.to_s
    @membership = membership
    @reason = reason.to_s.strip
    @effective_from = effective_from
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?

    ActiveRecord::Base.transaction do
      current = @departure.team_assignments.current.find_by(assignment_role: @role)
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        departure: @departure,
        memberships: [ @membership, current&.agency_membership ].compact,
        team_assignments: [ current ].compact
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
      raise Error.new("Team assignments can only be replaced on a draft or planning departure.", code: :invalid_state)
    end
    ensure_eligible_team_member!(@membership, @departure.office)

    current = @departure.team_assignments.current.find_by(assignment_role: @role)
    raise Error.new("There is no current assignment to replace.", code: :invalid_state) unless current

    replacement = replace_locked!(
      departure: @departure,
      current:,
      membership: @membership,
      assigned_by: actor,
      reason: @reason,
      effective_from: @effective_from.presence || OfficeDate.today(@departure.office)
    )
    audit!(
      agency: @agency,
      action: "departure.team_member_replaced",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "assignment_role" => @role,
        "ended_assignment_id" => current.id,
        "assignment_id" => replacement.id,
        "agency_membership_id" => @membership.id,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :replaced, departure: @departure, assignment: replacement)
  end

  def replace_locked!(departure:, current:, membership:, assigned_by:, reason:, effective_from:)
    ended_on = [ effective_from, current.effective_from ].max
    current.end!(ended_by: assigned_by, reason:, ended_on:)
    departure.team_assignments.create!(
      agency: @agency,
      agency_membership: membership,
      membership_status: "active",
      assignment_role: current.assignment_role,
      member_name_snapshot: membership.agency_display_name,
      effective_from:,
      assigned_at: Time.current,
      assigned_by_membership: assigned_by
    )
  end
end
