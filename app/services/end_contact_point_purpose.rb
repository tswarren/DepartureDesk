class EndContactPointPurpose < DirectoryCommand
  def initialize(agency:, party:, contact_point:, assignment:, inclusive_end_on:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @party = party
    @contact_point = contact_point
    @assignment = assignment
    @inclusive_end_on = inclusive_end_on
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point, @assignment ]) { perform }
  end

  def call_locked!
    perform
  end

  private

  def perform
    ensure_contact_point_on_party!(@party, @contact_point)
    unless @assignment.contact_point_id == @contact_point.id && @assignment.agency_id == @agency.id
      raise Error.new("That purpose assignment is not part of this contact point.", code: :not_found)
    end
    unless @assignment.record_valid?
      raise Error.new("Only a current purpose assignment can be ended.", code: :invalid)
    end
    raise Error.new("Enter a reason for ending this purpose.", code: :invalid) if @reason.blank?

    exclusive_until = DirectoryDate.exclusive_until(@inclusive_end_on)
    raise Error.new("Choose an end date.", code: :invalid) if exclusive_until.blank?

    from = @assignment.effective_from || DirectoryDate.today(@agency)
    if exclusive_until <= from
      raise Error.new("The end date must be on or after the start date.", code: :invalid)
    end

    @assignment.update!(
      effective_until: exclusive_until,
      ended_at: Time.current,
      ended_by_membership: actor_membership!(@agency),
      ending_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.contact_purpose_ended",
      subject: @assignment,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => @contact_point.id,
        "assignment_id" => @assignment.id,
        "purpose" => @assignment.purpose,
        "effective_until" => exclusive_until.iso8601
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point, purpose_assignment: @assignment)
  end
end
