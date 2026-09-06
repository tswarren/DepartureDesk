class VoidPartyRelationship < DirectoryCommand
  def initialize(agency:, relationship:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @relationship = relationship
    @reason = reason.to_s.strip
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(
      @agency,
      parties: [ @relationship.origin_party, @relationship.related_party ],
      records: [ @relationship ]
    ) { perform }
  end

  private

  def perform
    unless @relationship.agency_id == @agency.id
      raise Error.new("That relationship is not part of this agency.", code: :not_found)
    end
    unless @relationship.record_valid?
      raise Error.new("That relationship has already been corrected.", code: :conflict)
    end
    raise Error.new("Enter a reason for voiding this relationship.", code: :invalid) if @reason.blank?

    @relationship.update!(
      record_status: "voided",
      corrected_at: Time.current,
      corrected_by_membership: actor_membership!(@agency),
      correction_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.relationship_voided",
      subject: @relationship,
      details: {
        "relationship_id" => @relationship.id,
        "origin_party_id" => @relationship.origin_party_id,
        "related_party_id" => @relationship.related_party_id
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @relationship.origin_party, relationship: @relationship)
  end
end
