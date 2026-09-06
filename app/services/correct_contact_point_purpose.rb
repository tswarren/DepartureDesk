class CorrectContactPointPurpose < DirectoryCommand
  def initialize(agency:, party:, contact_point:, assignment:, reason:, actor: nil, actor_identifier: nil, privileged: false, purpose: nil, priority: nil, effective_from: nil, effective_until: nil)
    @agency = agency
    @party = party
    @contact_point = contact_point
    @assignment = assignment
    @reason = reason.to_s.strip
    @purpose = purpose
    @priority = priority
    @effective_from = effective_from
    @effective_until = effective_until
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @party ], records: [ @contact_point, @assignment ]) { perform }
  end

  private

  def perform
    ensure_contact_point_on_party!(@party, @contact_point)
    unless @assignment.contact_point_id == @contact_point.id && @assignment.agency_id == @agency.id
      raise Error.new("That purpose assignment is not part of this contact point.", code: :not_found)
    end
    unless @assignment.record_valid?
      raise Error.new("That purpose assignment has already been corrected.", code: :conflict)
    end
    raise Error.new("Enter a correction reason.", code: :invalid) if @reason.blank?

    purpose = (@purpose.presence || @assignment.purpose).to_s
    priority = (@priority.presence || @assignment.priority).to_i
    from = @effective_from.presence || @assignment.effective_from
    until_date = @effective_until.nil? ? @assignment.effective_until : @effective_until

    replacement = ContactPointPurposeAssignment.create!(
      agency: @agency,
      party: @party,
      contact_point: @contact_point,
      contact_kind: @contact_point.contact_kind,
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
      action: "directory.contact_purpose_corrected",
      subject: @assignment,
      details: {
        "party_id" => @party.id,
        "contact_point_id" => @contact_point.id,
        "assignment_id" => @assignment.id,
        "replacement_assignment_id" => replacement.id,
        "purpose" => purpose
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @party, contact_point: @contact_point, purpose_assignment: replacement)
  end
end
