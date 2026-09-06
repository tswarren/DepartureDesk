class CorrectRelationshipPurpose < DirectoryCommand
  def initialize(agency:, relationship:, assignment:, reason:, actor: nil, actor_identifier: nil, privileged: false, purpose: nil, priority: nil, effective_from: nil, effective_until: nil)
    @agency = agency
    @relationship = relationship
    @assignment = assignment
    @reason = reason.to_s.strip
    @purpose = purpose
    @priority = priority
    @effective_from = effective_from
    @effective_until = effective_until
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
      raise Error.new("That purpose assignment has already been corrected.", code: :conflict)
    end
    raise Error.new("Enter a correction reason.", code: :invalid) if @reason.blank?

    purpose = (@purpose.presence || @assignment.purpose).to_s
    priority = (@priority.presence || @assignment.priority).to_i
    from = @effective_from.presence || @assignment.effective_from
    until_date = @effective_until.nil? ? @assignment.effective_until : @effective_until
    unless DirectoryRange.contained?(from, until_date, @relationship.effective_from, @relationship.effective_until)
      raise Error.new("A purpose cannot outlive the relationship.", code: :invalid)
    end

    replacement = RelationshipPurposeAssignment.create!(
      agency: @agency,
      party_relationship: @relationship,
      organization_party: @relationship.related_party,
      purpose:,
      priority: 99,
      effective_from: from,
      effective_until: until_date,
      record_status: "valid"
    )
    @assignment.update!(
      record_status: "superseded",
      superseded_by_assignment: replacement,
      corrected_at: Time.current,
      corrected_by_membership: actor_membership!(@agency),
      correction_reason: @reason
    )
    replacement.update!(priority:)
    audit!(
      agency: @agency,
      action: "directory.relationship_purpose_corrected",
      subject: @assignment,
      details: {
        "relationship_id" => @relationship.id,
        "assignment_id" => @assignment.id,
        "replacement_assignment_id" => replacement.id,
        "purpose" => purpose
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @relationship.origin_party, relationship: @relationship, purpose_assignment: replacement)
  end
end
