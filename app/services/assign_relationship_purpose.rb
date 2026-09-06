class AssignRelationshipPurpose < DirectoryCommand
  def initialize(agency:, relationship:, purpose:, priority:, actor: nil, actor_identifier: nil, privileged: false, effective_from: nil, effective_until: nil, replace_primary: false)
    @agency = agency
    @relationship = relationship
    @purpose = purpose.to_s
    @priority = priority.to_i
    @effective_from = effective_from
    @effective_until = effective_until
    @replace_primary = replace_primary
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(
      @agency,
      parties: [ @relationship.origin_party, @relationship.related_party ],
      records: [ @relationship ]
    ) { perform }
  end

  def call_locked!
    perform
  end

  private

  def perform
    unless @relationship.agency_id == @agency.id
      raise Error.new("That relationship is not part of this agency.", code: :not_found)
    end
    unless @relationship.purpose_eligible? && @relationship.record_valid?
      raise Error.new("Purposes can only be assigned to an organization affiliation or contact.", code: :invalid)
    end
    unless RelationshipPurposeAssignment::PURPOSES.include?(@purpose)
      raise Error.new("Choose a relationship purpose.", code: :invalid)
    end
    raise Error.new("Priority must be a positive integer.", code: :invalid) if @priority < 1

    from = @effective_from.presence || DirectoryDate.today(@agency)
    until_date = @effective_until
    unless DirectoryRange.contained?(from, until_date, @relationship.effective_from, @relationship.effective_until)
      raise Error.new("A purpose cannot outlive the relationship.", code: :invalid)
    end

    overlapping = overlapping_primaries(from, until_date)
    if @priority == 1 && overlapping.any? && !@replace_primary
      raise Error.new("A primary contact is already assigned for that purpose.", code: :conflict)
    end

    actor = actor_membership!(@agency) if @replace_primary && overlapping.any?
    to_supersede = []
    overlapping.each do |assignment|
      next unless @replace_primary
      if assignment.effective_from.blank? || assignment.effective_from < from
        assignment.update!(
          effective_until: from,
          ended_at: Time.current,
          ended_by_membership: actor,
          ending_reason: "Replaced as primary"
        )
      else
        to_supersede << assignment
      end
    end

    assignment = RelationshipPurposeAssignment.create!(
      agency: @agency,
      party_relationship: @relationship,
      organization_party: @relationship.related_party,
      purpose: @purpose,
      priority: to_supersede.any? ? 99 : @priority,
      effective_from: from,
      effective_until: until_date,
      record_status: "valid"
    )
    to_supersede.each do |existing|
      existing.update!(
        record_status: "superseded",
        superseded_by_assignment: assignment,
        corrected_at: Time.current,
        corrected_by_membership: actor,
        correction_reason: "Replaced as primary"
      )
    end
    assignment.update!(priority: @priority) if assignment.priority != @priority

    audit!(
      agency: @agency,
      action: "directory.relationship_purpose_assigned",
      subject: assignment,
      details: {
        "relationship_id" => @relationship.id,
        "assignment_id" => assignment.id,
        "organization_party_id" => @relationship.related_party_id,
        "purpose" => assignment.purpose,
        "priority" => assignment.priority
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: @relationship.origin_party, relationship: @relationship, purpose_assignment: assignment)
  end

  def overlapping_primaries(from, until_date)
    return [] unless @priority == 1

    RelationshipPurposeAssignment
      .where(
        agency_id: @agency.id,
        organization_party_id: @relationship.related_party_id,
        purpose: @purpose,
        record_status: "valid",
        priority: 1
      )
      .where("daterange(effective_from, effective_until, '[)') && daterange(?::date, ?::date, '[)')", from, until_date)
      .to_a
  end
end
