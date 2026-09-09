class CancelDeparture < DepartureCommand
  ENDING_REASON = "departure_cancelled"

  def initialize(agency:, departure:, reason:, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @reason = reason.to_s.strip
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?

    team = @departure.team_assignments.current.to_a
    roles = @departure.party_role_assignments.current.to_a
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        program: @departure.travel_program,
        departure: @departure,
        parties: roles.map(&:party),
        memberships: team.map(&:agency_membership),
        team_assignments: team,
        party_role_assignments: roles
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
      raise Error.new("Only a draft or planning departure can be cancelled in this slice.", code: :invalid_state)
    end

    ended_on = OfficeDate.today(@departure.office)
    ended_team_ids = []
    ended_role_ids = []
    @departure.team_assignments.current.order(:id).each do |assignment|
      assignment.end!(ended_by: actor, reason: ENDING_REASON, ended_on:)
      ended_team_ids << assignment.id
    end
    @departure.party_role_assignments.current.order(:id).each do |assignment|
      assignment.end!(ended_by: actor, reason: ENDING_REASON, ended_on:)
      ended_role_ids << assignment.id
    end

    @departure.update!(
      status: "cancelled",
      status_reason: @reason,
      status_changed_at: Time.current,
      status_changed_by_membership: actor,
      owning_office_status: nil,
      travel_program_status: nil
    )
    audit!(
      agency: @agency,
      action: "departure.cancelled",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "reason" => @reason,
        "ended_team_assignment_ids" => ended_team_ids,
        "ended_party_role_assignment_ids" => ended_role_ids
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure)
  end
end
