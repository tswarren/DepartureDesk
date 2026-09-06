class CreatePartyRelationship < DirectoryCommand
  def initialize(agency:, origin_party:, related_party:, relationship_kind:, actor: nil, actor_identifier: nil, privileged: false, relationship_label: nil, title: nil, notes: nil, effective_from: nil, effective_until: nil)
    @agency = agency
    @origin_party = origin_party
    @related_party = related_party
    @relationship_kind = relationship_kind.to_s
    @relationship_label = relationship_label.presence
    @title = title
    @notes = notes
    @effective_from = effective_from
    @effective_until = effective_until
    assign_command_actors(actor:, actor_identifier:, privileged:)
  end

  def call
    with_directory_locks(@agency, parties: [ @origin_party, @related_party ]) { perform }
  end

  def call_locked!
    perform
  end

  private

  def perform
    unless PartyRelationship::KINDS.include?(@relationship_kind)
      raise Error.new("Choose a relationship kind.", code: :invalid)
    end
    expected = PartyRelationship.pair_for(@relationship_kind)
    if @origin_party.party_kind != expected[0] || @related_party.party_kind != expected[1]
      raise Error.new("Those parties cannot be related that way.", code: :invalid)
    end
    if @origin_party.id == @related_party.id
      raise Error.new("A party cannot be related to itself.", code: :invalid)
    end

    origin = @origin_party
    related = @related_party
    label = label_for_kind

    if @relationship_kind == "family" && %w[spouse_of partner_of].include?(label) && origin.id > related.id
      origin, related = related, origin
    end

    from = @effective_from.presence
    until_date = @effective_until
    if until_date.present? && from.present? && until_date <= from
      raise Error.new("The end date must be after the start date.", code: :invalid)
    end

    if @relationship_kind == "parent_organization" && parent_cycle?(origin, related, from, until_date)
      raise Error.new("That parent organization would create a cycle.", code: :invalid)
    end

    relationship = PartyRelationship.create!(
      agency: @agency,
      origin_party: origin,
      origin_party_kind: origin.party_kind,
      related_party: related,
      related_party_kind: related.party_kind,
      relationship_kind: @relationship_kind,
      relationship_label: label,
      title: @title,
      notes: @notes,
      effective_from: from,
      effective_until: until_date,
      record_status: "valid"
    )
    audit!(
      agency: @agency,
      action: "directory.relationship_created",
      subject: relationship,
      details: {
        "origin_party_id" => origin.id,
        "related_party_id" => related.id,
        "relationship_id" => relationship.id,
        "relationship_kind" => relationship.relationship_kind,
        "relationship_label" => relationship.relationship_label
      },
      **actor_audit_args
    )
    CommandResult.new(status: :created, party: origin, relationship:)
  end

  def label_for_kind
    case @relationship_kind
    when "family"
      unless PartyRelationship::FAMILY_LABELS.include?(@relationship_label)
        raise Error.new("Choose a family relationship.", code: :invalid)
      end
      @relationship_label
    when "organization_affiliation"
      unless PartyRelationship::AFFILIATION_LABELS.include?(@relationship_label)
        raise Error.new("Choose an affiliation.", code: :invalid)
      end
      @relationship_label
    else
      nil
    end
  end

  def parent_cycle?(child, parent, from, until_date)
    return true if child.id == parent.id

    visited = {}
    queue = [ parent.id ]
    while (current_id = queue.shift)
      return true if current_id == child.id
      next if visited[current_id]
      visited[current_id] = true
      PartyRelationship.record_valid.where(
        agency_id: @agency.id,
        relationship_kind: "parent_organization",
        origin_party_id: current_id
      ).find_each do |relationship|
        next unless DirectoryRange.overlap?(from, until_date, relationship.effective_from, relationship.effective_until)

        queue << relationship.related_party_id
      end
    end
    false
  end
end
