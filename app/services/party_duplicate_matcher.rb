class PartyDuplicateMatcher
  STRENGTHS = %w[none possible strong hard_conflict].freeze
  CANDIDATE_LIMIT = 10

  Candidate = Struct.new(
    :party_id,
    :display_name,
    :party_kind,
    :status,
    :primary_contact,
    :signals,
    :strength,
    keyword_init: true
  )

  Result = Struct.new(:strength, :candidates, keyword_init: true) do
    def none?
      strength == "none"
    end

    def possible?
      strength == "possible"
    end

    def strong?
      strength == "strong"
    end

    def hard_conflict?
      strength == "hard_conflict"
    end

    def candidate_ids
      candidates.map(&:party_id)
    end
  end

  def self.website_host(value)
    raw = value.to_s.strip
    return if raw.blank?

    raw = "https://#{raw}" unless raw.match?(/\A[a-z][a-z0-9+.-]*:\/\//i)
    host = URI.parse(raw).host.to_s.downcase.delete_prefix("www.")
    host.presence
  rescue URI::InvalidURIError
    nil
  end

  def initialize(agency:, party_kind:, attributes:, party_ids: nil, limit: CANDIDATE_LIMIT)
    @agency = agency
    @party_kind = party_kind.to_s
    @attributes = attributes.to_h.symbolize_keys
    @party_ids = Array(party_ids).presence
    @limit = limit
  end

  def call
    return Result.new(strength: "none", candidates: []) if @party_ids && @party_ids.empty?

    candidates = case @party_kind
    when "person" then person_candidates
    when "household" then household_candidates
    when "organization" then organization_candidates
    else
      []
    end

    Result.new(strength: overall_strength(candidates), candidates:)
  end

  private

  def person_candidates
    given = PartyName.normalize(@attributes[:given_name])
    family = PartyName.normalize(@attributes[:family_name])
    return [] if given.blank? || family.blank?

    proposed_display = PartyName.normalize(
      PartyName.person(
        given_name: @attributes[:given_name],
        family_name: @attributes[:family_name],
        preferred_name: @attributes[:preferred_name],
        middle_name: @attributes[:middle_name]
      ).display_name
    )
    proposed_dob = parse_date(@attributes[:date_of_birth])
    scope = matching_people(given:, family:, display: proposed_display)
    strong_scope = proposed_dob.present? ? scope.where(date_of_birth: proposed_dob) : nil

    merge_strong_and_possible(scope, strong_scope:).filter_map do |person|
      display_match = PartyName.normalize(person.party.display_name) == proposed_display
      name_match = PartyName.normalize(person.given_name) == given &&
        PartyName.normalize(person.family_name) == family
      next unless display_match || name_match

      dob_match = proposed_dob.present? && person.date_of_birth.present? && person.date_of_birth == proposed_dob
      strength = dob_match ? "strong" : "possible"
      signals = [ "name" ]
      signals << "date_of_birth" if dob_match
      candidate_for(person.party, strength:, signals:)
    end
  end

  def household_candidates
    name = PartyName.normalize(@attributes[:name])
    return [] if name.blank?

    matching_households(name).filter_map do |household|
      next unless PartyName.normalize(household.name) == name

      candidate_for(household.party, strength: "possible", signals: [ "name" ])
    end
  end

  def organization_candidates
    legal = PartyName.normalize(@attributes[:legal_name])
    trading = PartyName.normalize(@attributes[:trading_name])
    return [] if legal.blank? && trading.blank?

    proposed_host = self.class.website_host(@attributes[:website])
    scope = matching_organizations(legal:, trading:)
    strong_scope = website_host_scope(scope, proposed_host)

    merge_strong_and_possible(
      scope,
      strong_scope:,
      verify_strong: ->(organization) {
        proposed_host.present? && self.class.website_host(organization.website) == proposed_host
      }
    ).filter_map do |organization|
      legal_match = legal.present? && PartyName.normalize(organization.legal_name) == legal
      trading_match = trading.present? && organization.trading_name.present? &&
        PartyName.normalize(organization.trading_name) == trading
      next unless legal_match || trading_match

      host_match = proposed_host.present? && self.class.website_host(organization.website) == proposed_host
      strength = host_match ? "strong" : "possible"
      signals = [ "name" ]
      signals << "website" if host_match
      candidate_for(organization.party, strength:, signals:)
    end
  end

  def matching_people(given:, family:, display:)
    people = Person.arel_table
    parties = Party.arel_table
    name_match = sql_normalized(people[:given_name]).eq(given)
      .and(sql_normalized(people[:family_name]).eq(family))
    display_match = sql_normalized(parties[:display_name]).eq(display)
    scoped_kind(@agency.people).where(name_match.or(display_match))
  end

  def matching_households(name)
    households = Household.arel_table
    finish_matches(scoped_kind(@agency.households).where(sql_normalized(households[:name]).eq(name)))
  end

  def matching_organizations(legal:, trading:)
    organizations = Organization.arel_table
    scope = scoped_kind(@agency.organizations)
    predicates = []
    predicates << sql_normalized(organizations[:legal_name]).eq(legal) if legal.present?
    predicates << sql_normalized(organizations[:trading_name]).eq(trading) if trading.present?
    return scope.none if predicates.empty?

    scope.where(predicates.reduce { |combined, predicate| combined.or(predicate) })
  end

  def scoped_kind(scope)
    scope = scope.joins(:party)
    scope = scope.where(party_id: @party_ids) if @party_ids
    scope
  end

  def finish_matches(scope)
    ordered_matches(scope).limit(@limit)
  end

  def ordered_matches(scope)
    scope.includes(party: party_summary_includes).order("parties.sort_name", "parties.id")
  end

  def merge_strong_and_possible(scope, strong_scope: nil, verify_strong: nil)
    strong_records = []
    if strong_scope
      fetched = ordered_matches(strong_scope)
      fetched = verify_strong ? fetched.to_a.select { |record| verify_strong.call(record) } : fetched.limit(@limit).to_a
      strong_records = fetched.first(@limit)
    end

    remaining = @limit - strong_records.size
    possible_records = if remaining.positive?
      possible_scope = strong_records.any? ? scope.where.not(party_id: strong_records.map(&:party_id)) : scope
      ordered_matches(possible_scope).limit(remaining).to_a
    else
      []
    end

    strong_records + possible_records
  end

  def website_host_scope(scope, host)
    return if host.blank?

    pattern = "%#{Organization.sanitize_sql_like(host)}%"
    lowered = Arel::Nodes::NamedFunction.new("lower", [ Organization.arel_table[:website] ])
    scope.where(lowered.matches(pattern, nil, true))
  end

  def sql_normalized(column)
    normalized = Arel::Nodes::NamedFunction.new("normalize", [ column, Arel.sql("NFKC") ])
    trimmed = Arel::Nodes::NamedFunction.new("btrim", [ normalized ])
    collapsed = Arel::Nodes::NamedFunction.new(
      "regexp_replace",
      [
        trimmed,
        Arel::Nodes.build_quoted("\\s+"),
        Arel::Nodes.build_quoted(" "),
        Arel::Nodes.build_quoted("g")
      ]
    )
    Arel::Nodes::NamedFunction.new("lower", [ collapsed ])
  end

  def party_summary_includes
    { contact_point_purpose_assignments: { contact_point: [ :email_address, :phone_number, :postal_address ] } }
  end

  def candidate_for(party, strength:, signals:)
    Candidate.new(
      party_id: party.id,
      display_name: party.display_name,
      party_kind: party.party_kind,
      status: party.status,
      primary_contact: primary_contact_for(party),
      signals:,
      strength:
    )
  end

  def primary_contact_for(party)
    today = DirectoryDate.today(@agency)
    assignment = party.contact_point_purpose_assignments.select { |row|
      row.current_on?(today) && row.primary? && row.contact_point&.eligible_destination?
    }.min_by { |row| [ row.contact_kind, row.purpose, row.id.to_s ] }
    assignment&.contact_point&.display_value.to_s.split("\n").first.presence
  end

  def parse_date(value)
    return value if value.is_a?(Date)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue Date::Error, ArgumentError
    nil
  end

  def overall_strength(candidates)
    strengths = candidates.map(&:strength)
    return "none" if strengths.empty?
    return "hard_conflict" if strengths.include?("hard_conflict")
    return "strong" if strengths.include?("strong")

    "possible"
  end
end
