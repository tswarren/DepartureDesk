class PartyDeactivationDependencies
  SAMPLE_SIZE = 5
  Checker = Data.define(:name, :runner)

  class << self
    def checkers
      @checkers ||= []
    end

    def register(name, &block)
      unregister(name)
      checkers << Checker.new(name.to_s, block)
    end

    def unregister(name)
      checkers.reject! { |checker| checker.name == name.to_s }
    end
  end

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
      items = self.class.checkers.flat_map { |checker| items_for(checker) }
      { total: items.size, labels: items.first(SAMPLE_SIZE) }
    end
  end

  def items_for(checker)
    Array(
      checker.runner.call(
        agency: @agency,
        party: @party,
        today: @today
      )
    ).compact
  rescue StandardError
    [ "#{checker.name} could not be verified" ]
  end
end

PartyDeactivationDependencies.register("membership") do |party:, **|
  membership = party.person&.agency_membership
  next [] if membership.blank?

  [ "Team membership (#{membership.agency_display_name})" ]
end

PartyDeactivationDependencies.register("roles") do |party:, **|
  items = []
  items << "#{party.display_name} (client)" if party.client_profile&.active?
  items << "#{party.display_name} (supplier)" if party.supplier_profile&.active?
  items
end

PartyDeactivationDependencies.register("household_membership") do |party:, today:, **|
  PartyRelationship.current_on(today).where(relationship_kind: "household_member").involving(party)
    .includes(:origin_party, :related_party)
    .order(:id)
    .map { |relationship|
      other = relationship.origin_party_id == party.id ? relationship.related_party : relationship.origin_party
      "#{other.display_name} (household membership)"
    }
end

PartyDeactivationDependencies.register("organization_relationships") do |party:, today:, **|
  PartyRelationship.current_on(today)
    .where(relationship_kind: %w[organization_contact organization_affiliation])
    .involving(party)
    .includes(:origin_party, :related_party)
    .order(:id)
    .map { |relationship|
      other = relationship.origin_party_id == party.id ? relationship.related_party : relationship.origin_party
      "#{other.display_name} (#{relationship.relationship_kind.tr("_", " ")})"
    }
end

PartyDeactivationDependencies.register("departure_party_roles") do |agency:, party:, **|
  DeparturePartyRoleAssignment.current
    .joins(:departure)
    .where(
      agency_id: agency.id,
      party_id: party.id,
      departures: { status: Departure::NONTERMINAL_STATUSES }
    )
    .includes(:departure)
    .order(:id)
    .map { |assignment|
      "#{assignment.departure.departure_reference} #{assignment.departure.name} (#{assignment.role.tr("_", " ")})"
    }
end

PartyDeactivationDependencies.register("supplier_planning") do |agency:, party:, **|
  supplier_items = SupplierArrangement.nonterminal
    .joins(:departure)
    .where(agency_id: agency.id, supplier_party_id: party.id, departures: { status: Departure::NONTERMINAL_STATUSES })
    .includes(:departure)
    .order(:id)
    .map { |arrangement| "#{arrangement.departure.departure_reference} #{arrangement.name} (supplier arrangement)" }

  provider_items = SupplierArrangement.nonterminal
    .joins(:departure)
    .where(agency_id: agency.id, service_provider_party_id: party.id, departures: { status: Departure::NONTERMINAL_STATUSES })
    .includes(:departure)
    .order(:id)
    .map { |arrangement| "#{arrangement.departure.departure_reference} #{arrangement.name} (service provider)" }

  supplier_items + provider_items
end

PartyDeactivationDependencies.register("primary_purposes") do |party:, today:, **|
  RelationshipPurposeAssignment.record_valid.primary
    .joins(:party_relationship)
    .where("relationship_purpose_assignments.effective_from IS NULL OR relationship_purpose_assignments.effective_from <= ?", today)
    .where("relationship_purpose_assignments.effective_until IS NULL OR relationship_purpose_assignments.effective_until > ?", today)
    .where(
      "party_relationships.origin_party_id = :id OR party_relationships.related_party_id = :id OR relationship_purpose_assignments.organization_party_id = :id",
      id: party.id
    )
    .includes(:party_relationship)
    .order(:id)
    .map { |assignment| "#{assignment.purpose_label} primary" }
end
