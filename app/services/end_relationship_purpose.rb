class EndRelationshipPurpose < DirectoryCommand
  def initialize(agency:, relationship:, assignment:, inclusive_end_on:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @relationship = relationship
    @assignment = assignment
    @inclusive_end_on = inclusive_end_on
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(
      @agency,
      parties: [ @relationship.origin_party, @relationship.related_party ],
      records: [ @relationship, @assignment ]
    ) { perform }
  end

  private

  def perform
    unless @assignment.relationship_id == @relationship.id && @relationship.agency_id == @agency.id
      raise Error.new("That purpose assignment is not part of this relationship.", code: :not_found)
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
    unless DirectoryRange.contained?(@assignment.effective_from, exclusive_until, @relationship.effective_from, @relationship.effective_until)
      raise Error.new("A purpose cannot outlive the relationship.", code: :invalid)
    end

    @assignment.update!(
      effective_until: exclusive_until,
      ended_at: Time.current,
      ended_by_membership: actor_membership!(@agency),
      ending_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.relationship_purpose_ended",
      subject: @assignment,
      details: {
        "relationship_id" => @relationship.id,
        "assignment_id" => @assignment.id,
        "purpose" => @assignment.purpose,
        "effective_until" => exclusive_until.iso8601
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @relationship.origin_party, relationship: @relationship, purpose_assignment: @assignment)
  end
end
