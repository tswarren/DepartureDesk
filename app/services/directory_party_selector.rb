class DirectoryPartySelector
  MODES = %w[
    any
    client
    active_client
    supplier
    active_supplier
    supplier_contact
    team_member
    person
    organization
  ].freeze
  PAGE_SIZE = 50

  Result = Struct.new(
    :party_id,
    :display_name,
    :sort_name,
    :party_kind,
    :client_status,
    :supplier_status,
    :team_member,
    keyword_init: true
  )

  def initialize(agency:, mode: "any", household_allowed: true, q: nil, exclude_party_id: nil, limit: PAGE_SIZE)
    @agency = agency
    @mode = mode.to_s
    @household_allowed = household_allowed
    @q = q.to_s.strip
    @exclude_party_id = exclude_party_id
    @limit = limit
  end

  def results
    unless MODES.include?(@mode)
      raise ArgumentError, "Unknown party selector mode."
    end

    scope = @agency.parties.includes(:client_profile, :supplier_profile, person: :agency_membership).order(:sort_name, :id)
    scope = scope.where.not(id: @exclude_party_id) if @exclude_party_id.present?
    scope = apply_mode(scope)
    scope = apply_household(scope)
    scope = apply_query(scope)
    scope.limit(@limit).map { |party| result_for(party) }
  end

  private

  def apply_mode(scope)
    case @mode
    when "any"
      scope
    when "client"
      scope.joins(:client_profile)
    when "active_client"
      scope.joins(:client_profile).where(client_profiles: { status: "active" })
    when "supplier"
      scope.joins(:supplier_profile)
    when "active_supplier"
      scope.joins(:supplier_profile).where(supplier_profiles: { status: "active" })
    when "supplier_contact"
      contact_ids = PartyRelationship
        .current_on(DirectoryDate.today(@agency))
        .where(relationship_kind: %w[organization_contact organization_affiliation])
        .where(related_party_id: @agency.supplier_profiles.select(:party_id))
        .select(:origin_party_id)
      scope.where(party_kind: "person", id: contact_ids)
    when "team_member"
      scope.where(party_kind: "person", id: @agency.agency_memberships.select(:person_party_id))
    when "person"
      scope.where(party_kind: "person")
    when "organization"
      scope.where(party_kind: "organization")
    else
      scope.none
    end
  end

  def apply_household(scope)
    return scope if @household_allowed
    return scope if %w[person organization team_member supplier_contact].include?(@mode)

    scope.where.not(party_kind: "household")
  end

  def apply_query(scope)
    return scope if @q.blank?

    pattern = "#{sanitize_like(@q)}%"
    scope.where("parties.display_name ILIKE :q OR parties.sort_name ILIKE :q", q: pattern)
  end

  def sanitize_like(value)
    value.gsub(/[%_\\]/) { |char| "\\#{char}" }
  end

  def result_for(party)
    Result.new(
      party_id: party.id,
      display_name: party.display_name,
      sort_name: party.sort_name,
      party_kind: party.party_kind,
      client_status: party.client_profile&.status,
      supplier_status: party.supplier_profile&.status,
      team_member: party.person&.agency_membership.present?
    )
  end
end
