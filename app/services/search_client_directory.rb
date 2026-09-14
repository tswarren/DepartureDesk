class SearchClientDirectory
  Result = Data.define(:id, :display_name, :status, :client_reference, :rank, :kind)
  Outcome = Data.define(:records, :truncated)
  LIMIT = 50

  STATUSES = %w[active inactive all].freeze

  def self.call(agency:, actor:, query:, status: "active")
    new(agency:, actor:, query:, status:).call
  end

  def initialize(agency:, actor:, query:, status:)
    @agency = agency
    @actor = actor
    @query = query.to_s
    @status = STATUSES.include?(status) ? status : "active"
    @can_see_contacts = actor.permitted?(:view_client_contact_details)
  end

  def call
    raise AgencyCommand::Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @query.blank? || @query.length > 100

    matches = []
    matches.concat(reference_matches)
    matches.concat(email_matches) if @can_see_contacts
    matches.concat(phone_matches) if @can_see_contacts
    matches.concat(name_matches)
    matches.concat(postal_matches) if @can_see_contacts
    ordered = matches.sort_by { |match| [ match.rank, match.status == "active" ? 0 : 1, match.display_name.to_s, match.id ] }
    unique = ordered.uniq(&:id)
    Outcome.new(records: unique.first(LIMIT), truncated: unique.size > LIMIT)
  end

  private

  def people
    scope = @agency.client_people.left_joins(:client)
    @status == "all" ? scope : scope.where(status: @status)
  end

  def reference_matches
    reference = @query.strip.upcase
    return [] unless reference.match?(Client::REFERENCE_FORMAT)

    rows(people.where(clients: { client_reference: reference }), rank: 1, kind: "reference")
  end

  def email_matches
    email = @query.strip.downcase
    return [] unless email.include?("@")

    ids = ClientPersonEmailAddress.where(agency_id: @agency.id, normalized_address: email).select(:client_person_id)
    rows(people.where(id: ids), rank: 2, kind: "email")
  end

  def phone_matches
    digits = @query.gsub(/\D/, "")
    return [] if digits.length < 7

    ids = ClientPersonPhoneNumber.where(agency_id: @agency.id, normalized_number: "+#{digits}").or(
      ClientPersonPhoneNumber.where(agency_id: @agency.id).where("phone_digits_reversed LIKE ?", "#{digits.reverse}%")
    ).distinct.pluck(:client_person_id)
    rows(people.where(id: ids), rank: 3, kind: "phone")
  end

  def name_matches
    normalized = SearchNormalizer.normalize(@query)
    exact = rows(people.where(name_search_key: normalized), rank: 4, kind: "name")
    tsquery = prefix_tsquery
    return exact if tsquery.blank?

    prefix = rows(people.where("name_search_vector @@ to_tsquery('simple', ?)", tsquery), rank: 5, kind: "name_prefix")
    exact + prefix
  end

  def postal_matches
    key = SearchNormalizer.normalize(@query)
    return [] if key.blank?

    ids = ClientPersonPostalAddress.where(agency_id: @agency.id, postal_code_search_key: key)
      .or(ClientPersonPostalAddress.where(agency_id: @agency.id).where("locality_search_key LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(key)}%"))
      .select(:client_person_id)
    rows(people.where(id: ids), rank: 6, kind: "postal")
  end

  def rows(scope, rank:, kind:)
    scope.select("client_people.id, client_people.first_name, client_people.preferred_name, client_people.last_name, client_people.status, clients.client_reference").map do |person|
      Result.new(
        id: person.id,
        display_name: person.display_name,
        status: person.status,
        client_reference: person.read_attribute(:client_reference),
        rank: rank,
        kind: kind
      )
    end
  end

  def prefix_tsquery
    tokens = SearchNormalizer.tokens(@query)
    return if tokens.empty?

    lexemes = tokens.map { |token| quoted_lexeme(token) }
    return if lexemes.any?(&:nil?)

    lexemes.map { |lexeme| "#{lexeme}:*" }.join(" & ")
  rescue ActiveRecord::StatementInvalid
    nil
  end

  def quoted_lexeme(token)
    return if token.match?(/[&|!():*<>\\']/) && !token.match?(/\A[[:alnum:]\-]+\z/)

    escaped = token.gsub("'", "''")
    "'#{escaped}'"
  end
end
