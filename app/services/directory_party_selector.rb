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

  def initialize(agency:, mode: "any", household_allowed: true, q: nil, exclude_party_id: nil, limit: PAGE_SIZE, include_inactive: false, party_kind: nil)
    @agency = agency
    @mode = mode.to_s
    @household_allowed = household_allowed
    @q = q.to_s.strip
    @exclude_party_id = exclude_party_id
    @limit = limit
    @include_inactive = include_inactive
    @party_kind = party_kind.to_s.presence
  end

  def relation
    unless MODES.include?(@mode)
      raise ArgumentError, "Unknown party selector mode."
    end

    scope = @agency.parties.order(:sort_name, :id)
    scope = scope.active unless @include_inactive
    scope = scope.where.not(id: @exclude_party_id) if @exclude_party_id.present?
    scope = scope.where(party_kind: @party_kind) if Party::KINDS.include?(@party_kind.to_s)
    scope = apply_mode(scope)
    scope = apply_household(scope)
    apply_query(scope)
  end

  def results
    relation
      .includes(:client_profile, :supplier_profile, person: :agency_membership)
      .limit(@limit)
      .map { |party| result_for(party) }
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

    binds = {
      contains: "%#{sanitize_like(@q)}%",
      raw: @q,
      normalized_q: PartyName.normalize(@q),
      identifier_value: ExternalIdentifierRegistry.normalize("legacy_party_id", @q)
    }
    clauses = [
      "parties.display_name ILIKE :contains",
      "parties.sort_name ILIKE :contains",
      "similarity(parties.display_name, :raw) >= 0.3",
      "similarity(parties.sort_name, :raw) >= 0.3",
      "word_similarity(:raw, parties.display_name) >= 0.4",
      "word_similarity(:raw, parties.sort_name) >= 0.4",
      <<~SQL.squish,
        EXISTS (
          SELECT 1
          FROM party_alternate_names an
          WHERE an.party_id = parties.id
            AND an.agency_id = parties.agency_id
            AND an.status = 'active'
            AND (
              an.normalized_name ILIKE :contains
              OR an.name ILIKE :contains
              OR similarity(an.normalized_name, :normalized_q) >= 0.3
              OR an.normalized_name % :normalized_q
            )
        )
      SQL
      <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM external_identifiers ei
          LEFT JOIN client_profiles identifier_clients
            ON identifier_clients.id = ei.client_profile_id
          LEFT JOIN supplier_profiles identifier_suppliers
            ON identifier_suppliers.id = ei.supplier_profile_id
          WHERE ei.agency_id = parties.agency_id
            AND ei.status = 'active'
            AND ei.normalized_value = :identifier_value
            AND (
              ei.party_id = parties.id
              OR identifier_clients.party_id = parties.id
              OR identifier_suppliers.party_id = parties.id
            )
        )
      SQL
    ]

    if (email_value = normalized_email_query)
      binds[:email_value] = email_value
      clauses << <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM party_contact_points cp
          WHERE cp.party_id = parties.id
            AND cp.agency_id = parties.agency_id
            AND cp.status = 'active'
            AND cp.contact_kind = 'email'
            AND cp.normalized_value = :email_value
        )
      SQL
    end

    if (phone_value = normalized_phone_query)
      binds[:phone_value] = phone_value
      clauses << <<~SQL.squish
        EXISTS (
          SELECT 1
          FROM party_contact_points cp
          WHERE cp.party_id = parties.id
            AND cp.agency_id = parties.agency_id
            AND cp.status = 'active'
            AND cp.contact_kind = 'phone'
            AND cp.normalized_value = :phone_value
        )
      SQL
    end

    scope.where(clauses.join(" OR "), **binds)
  end

  def normalized_email_query
    EmailAddressNormalizer.normalize(@q)[:normalized_address]
  rescue EmailAddressNormalizer::Error
    nil
  end

  def normalized_phone_query
    return if @q.match?(/\A\D*\z/)

    PhoneNumberNormalizer.normalize(@q).normalized_digits
  rescue PhoneNumberNormalizer::Error
    nil
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
