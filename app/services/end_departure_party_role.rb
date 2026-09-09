class EndDeparturePartyRole < DepartureCommand
  def initialize(agency:, departure:, assignment:, reason:, replacement: nil, end_all_for_role: false, ended_on: nil, lock_version: nil, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @departure = departure
    @assignment = assignment
    @reason = reason.to_s.strip
    @replacement = replacement
    @end_all_for_role = end_all_for_role
    @ended_on = ended_on
    @lock_version = lock_version
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    raise Error.new("A reason is required.", code: :invalid) if @reason.blank?

    current = @departure.party_role_assignments.current.where(role: @assignment.role).to_a
    ActiveRecord::Base.transaction do
      with_departure_locks(
        @agency,
        offices: [ @departure.office ],
        departure: @departure,
        parties: [ @assignment.party, @replacement&.party ].compact,
        party_role_assignments: (current + [ @assignment, @replacement ]).compact
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
    unless @assignment.departure_id == @departure.id
      raise Error.new("That assignment is not part of this departure.", code: :invalid)
    end
    unless @assignment.current?
      raise Error.new("That assignment has already ended.", code: :invalid_state)
    end

    ended_on = @ended_on.presence || OfficeDate.today(@departure.office)
    siblings = @departure.party_role_assignments.current.where(role: @assignment.role).where.not(id: @assignment.id).to_a
    was_primary = @assignment.is_primary?

    if was_primary && siblings.any? && !@end_all_for_role
      unless @replacement&.current? && @replacement.departure_id == @departure.id && @replacement.role == @assignment.role && @replacement.id != @assignment.id
        raise Error.new("Choose a replacement primary or end every current assignment for this role.", code: :invalid)
      end
    end

    @assignment.end!(ended_by: actor, reason: @reason, ended_on:)
    if was_primary && siblings.any?
      if @end_all_for_role
        siblings.each { |sibling| sibling.end!(ended_by: actor, reason: @reason, ended_on:) }
      else
        @replacement.update!(is_primary: true)
      end
    end
    audit!(
      agency: @agency,
      action: "departure.party_role_ended",
      subject: @departure,
      details: {
        "departure_id" => @departure.id,
        "assignment_id" => @assignment.id,
        "role" => @assignment.role,
        "reason" => @reason
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, departure: @departure, assignment: @assignment)
  end
end
