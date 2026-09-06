class EndPartyRelationship < DirectoryCommand
  def initialize(agency:, relationship:, inclusive_end_on:, reason:, actor: nil, actor_identifier: nil, privileged: false)
    @agency = agency
    @relationship = relationship
    @inclusive_end_on = inclusive_end_on
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
      raise Error.new("Only a current relationship can be ended.", code: :invalid)
    end
    raise Error.new("Enter a reason for ending this relationship.", code: :invalid) if @reason.blank?

    exclusive_until = DirectoryDate.exclusive_until(@inclusive_end_on)
    raise Error.new("Choose an end date.", code: :invalid) if exclusive_until.blank?

    from = @relationship.effective_from || DirectoryDate.today(@agency)
    if exclusive_until <= from
      raise Error.new("The end date must be on or after the start date.", code: :invalid)
    end

    @relationship.update!(
      effective_until: exclusive_until,
      ended_at: Time.current,
      ended_by_membership: actor_membership!(@agency),
      ending_reason: @reason
    )
    audit!(
      agency: @agency,
      action: "directory.relationship_ended",
      subject: @relationship,
      details: {
        "relationship_id" => @relationship.id,
        "origin_party_id" => @relationship.origin_party_id,
        "related_party_id" => @relationship.related_party_id,
        "effective_until" => exclusive_until.iso8601
      },
      **actor_audit_args
    )
    CommandResult.new(status: :accepted, party: @relationship.origin_party, relationship: @relationship)
  end
end
