class CorrectPartyRelationship < DirectoryCommand
  def initialize(agency:, relationship:, reason:, actor: nil, actor_identifier: nil, privileged: false, origin_party: nil, related_party: nil, relationship_label: nil, title: nil, notes: nil, effective_from: nil, effective_until: nil)
    @agency = agency
    @relationship = relationship
    @reason = reason.to_s.strip
    @origin_party = origin_party
    @related_party = related_party
    @relationship_label = relationship_label
    @title = title
    @notes = notes
    @effective_from = effective_from
    @effective_until = effective_until
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    origin = @origin_party || @relationship.origin_party
    related = @related_party || @relationship.related_party
    with_directory_locks(@agency, parties: [ origin, related ], records: [ @relationship ]) { perform }
  end

  private

  def perform
    unless @relationship.agency_id == @agency.id
      raise Error.new("That relationship is not part of this agency.", code: :not_found)
    end
    unless @relationship.record_valid?
      raise Error.new("That relationship has already been corrected.", code: :conflict)
    end
    raise Error.new("Enter a correction reason.", code: :invalid) if @reason.blank?

    origin = @origin_party || @relationship.origin_party
    related = @related_party || @relationship.related_party
    actor = actor_membership!(@agency)
    @relationship.update!(
      record_status: "superseded",
      superseded_by_relationship: @relationship,
      corrected_at: Time.current,
      corrected_by_membership: actor,
      correction_reason: @reason
    )

    replacement = CreatePartyRelationship.new(
      agency: @agency,
      origin_party: origin,
      related_party: related,
      relationship_kind: @relationship.relationship_kind,
      relationship_label: @relationship_label.presence || @relationship.relationship_label,
      title: @title.nil? ? @relationship.title : @title,
      notes: @notes.nil? ? @relationship.notes : @notes,
      effective_from: @effective_from.nil? ? @relationship.effective_from : @effective_from,
      effective_until: @effective_until.nil? ? @relationship.effective_until : @effective_until,
      actor: @actor,
      actor_identifier: @actor_identifier,
      privileged: @privileged
    ).call_locked!.relationship

    @relationship.update!(superseded_by_relationship: replacement)
    reconcile_purposes!(replacement, actor)
    audit!(
      agency: @agency,
      action: "directory.relationship_corrected",
      subject: @relationship,
      details: {
        "relationship_id" => @relationship.id,
        "replacement_relationship_id" => replacement.id,
        "origin_party_id" => replacement.origin_party_id,
        "related_party_id" => replacement.related_party_id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: replacement.origin_party, relationship: replacement)
  end

  def reconcile_purposes!(replacement, actor)
    @relationship.purpose_assignments.record_valid.find_each do |assignment|
      next if DirectoryRange.contained?(assignment.effective_from, assignment.effective_until, replacement.effective_from, replacement.effective_until)

      assignment.update!(
        record_status: "voided",
        corrected_at: Time.current,
        corrected_by_membership: actor,
        correction_reason: "Relationship corrected"
      )
    end
  end
end
