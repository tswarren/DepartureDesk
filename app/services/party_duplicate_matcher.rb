class PartyDuplicateMatcher
  STRENGTHS = %w[none possible strong hard_conflict].freeze

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

  def initialize(agency:, party_kind:, attributes:)
    @agency = agency
    @party_kind = party_kind.to_s
    @attributes = attributes.to_h.symbolize_keys
  end

  def call
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

    matching_people.filter_map do |person|
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

    matching_households.filter_map do |household|
      next unless PartyName.normalize(household.name) == name

      candidate_for(household.party, strength: "possible", signals: [ "name" ])
    end
  end

  def organization_candidates
    legal = PartyName.normalize(@attributes[:legal_name])
    trading = PartyName.normalize(@attributes[:trading_name])
    return [] if legal.blank? && trading.blank?

    proposed_host = self.class.website_host(@attributes[:website])

    matching_organizations.filter_map do |organization|
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

  def matching_people
    @agency.people.includes(party: party_summary_includes).select do |person|
      PartyName.normalize(person.family_name) == PartyName.normalize(@attributes[:family_name]) ||
        PartyName.normalize(person.party.display_name) == PartyName.normalize(
          PartyName.person(
            given_name: @attributes[:given_name],
            family_name: @attributes[:family_name],
            preferred_name: @attributes[:preferred_name],
            middle_name: @attributes[:middle_name]
          ).display_name
        )
    end
  end

  def matching_households
    @agency.households.includes(party: party_summary_includes).select do |household|
      PartyName.normalize(household.name) == PartyName.normalize(@attributes[:name])
    end
  end

  def matching_organizations
    @agency.organizations.includes(party: party_summary_includes).select do |organization|
      legal = PartyName.normalize(@attributes[:legal_name])
      trading = PartyName.normalize(@attributes[:trading_name])
      (legal.present? && PartyName.normalize(organization.legal_name) == legal) ||
        (trading.present? && organization.trading_name.present? && PartyName.normalize(organization.trading_name) == trading)
    end
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
