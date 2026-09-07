class PartyDeactivationDependencies
  SAMPLE_SIZE = 5

  def initialize(agency:, party:)
    @agency = agency
    @party = party
    @today = DirectoryDate.today(agency)
  end

  def blocked?
    total.positive?
  end

  def message
    return "Resolve directory dependencies before deactivating this party." if total.zero?

    noun = total == 1 ? "dependency" : "dependencies"
    extra = total - labels.size
    suffix = extra.positive? ? ", and #{extra} more" : ""
    "Resolve #{total} #{noun} before deactivating this party: #{labels.join(", ")}#{suffix}."
  end

  def total
    summary[:total]
  end

  def labels
    summary[:labels]
  end

  private

  def summary
    @summary ||= begin
      items = []
      items.concat(membership_items)
      items.concat(role_items)
      items.concat(household_items)
      items.concat(organization_relationship_items)
      items.concat(primary_purpose_items)
      { total: items.size, labels: items.first(SAMPLE_SIZE) }
    end
  end

  def membership_items
    membership = @party.person&.agency_membership
    return [] if membership.blank?

    [ "Team membership (#{membership.agency_display_name})" ]
  end

  def role_items
    items = []
    if @party.client_profile&.active?
      items << "#{@party.display_name} (client)"
    end
    if @party.supplier_profile&.active?
      items << "#{@party.display_name} (supplier)"
    end
    items
  end

  def household_items
    scope = PartyRelationship.current_on(@today).where(relationship_kind: "household_member").involving(@party)
    scope.includes(:origin_party, :related_party).order(:id).map { |relationship|
      other = relationship.origin_party_id == @party.id ? relationship.related_party : relationship.origin_party
      "#{other.display_name} (household membership)"
    }
  end

  def organization_relationship_items
    scope = PartyRelationship.current_on(@today)
      .where(relationship_kind: %w[organization_contact organization_affiliation])
      .involving(@party)
    scope.includes(:origin_party, :related_party).order(:id).map { |relationship|
      other = relationship.origin_party_id == @party.id ? relationship.related_party : relationship.origin_party
      "#{other.display_name} (#{relationship.relationship_kind.tr("_", " ")})"
    }
  end

  def primary_purpose_items
    RelationshipPurposeAssignment.record_valid.primary
      .joins(:party_relationship)
      .where("relationship_purpose_assignments.effective_from IS NULL OR relationship_purpose_assignments.effective_from <= ?", @today)
      .where("relationship_purpose_assignments.effective_until IS NULL OR relationship_purpose_assignments.effective_until > ?", @today)
      .where(
        "party_relationships.origin_party_id = :id OR party_relationships.related_party_id = :id OR relationship_purpose_assignments.organization_party_id = :id",
        id: @party.id
      )
      .includes(:party_relationship)
      .order(:id)
      .map { |assignment|
        "#{assignment.purpose_label} primary"
      }
  end
end
