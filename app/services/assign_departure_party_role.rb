class AssignDeparturePartyRole < DepartureCommand
  def initialize(agency:, departure:, party:, role:, effective_from: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @party = party
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
        parties: [ @party ]
      ) { perform }
    end
  rescue ActiveRecord::StaleObjectError
    raise Error.new("This departure was updated by someone else.", code: :conflict)
  rescue ActiveRecord::StatementInvalid => error
    raise overlapping_party_role_error if overlapping_party_role_interval_violation?(error)

    raise
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def perform
    actor = actor_membership(@agency)
    ensure_office_access!(actor, @departure.office)
    ensure_fresh_lock!(@departure, @lock_version)
    unless @departure.nonterminal?
      raise Error.new("Party roles can only be added to a draft or planning departure.", code: :invalid_state)
    end
    unless DeparturePartyRoleAssignment::ROLES.include?(@role)
      raise Error.new("That party role is not valid.", code: :invalid)
    end
    unless @party.active?
      raise Error.new("Choose an active party.", code: :invalid)
    end
    if @role == "group_leader" && !@party.person?
      raise Error.new("A group leader must be a person.", code: :invalid)
    end

    effective_from = @effective_from.presence || OfficeDate.today(@departure.office)
    if overlapping_party_role_assignment?(effective_from)
      raise overlapping_party_role_error
    end

    current_for_role = @departure.party_role_assignments.current.where(role: @role)
    assignment = @departure.party_role_assignments.create!(
      agency: @agency,
      party: @party,
      party_kind: @party.party_kind,
      role: @role,
      party_display_name_snapshot: @party.display_name,
      is_primary: current_for_role.none?,
      effective_from:,
      assigned_at: Time.current,
      assigned_by_membership: actor
    )
    audit!(
      agency: @agency,
      action: "departure.party_role_assigned",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "assignment_id" => assignment.id,
        "role" => assignment.role,
        "party_id" => @party.id,
        "is_primary" => assignment.is_primary
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, departure: @departure, assignment:)
  end

  def overlapping_party_role_assignment?(effective_from)
    @departure.party_role_assignments
      .where(role: @role, party_id: @party.id)
      .where("effective_until IS NULL OR effective_until > ?", effective_from)
      .exists?
  end

  def overlapping_party_role_error
    Error.new("That party is already assigned to this role for an overlapping period.", code: :conflict)
  end
end
