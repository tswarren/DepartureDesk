class SearchClientDirectory
  Result = Data.define(:id, :display_name, :status, :client_reference, :rank, :kind)
  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1

  STATUSES = %w[active inactive all].freeze
  KINDS = {
    1 => "reference",
    2 => "email",
    3 => "phone",
    4 => "name",
    5 => "name_prefix",
    6 => "postal"
  }.freeze

  def self.call(agency:, actor:, query:, status: "active")
    new(agency:, actor:, query:, status:).call
  end

  def initialize(agency:, actor:, query:, status:)
    @agency = agency
    @actor = actor
    @query = query.to_s
    @status = STATUSES.include?(status) ? status : "active"
  end

  def call
    ensure_authorized!
    raise AgencyCommand::Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @query.blank? || @query.length > 100

    @can_see_contacts = @actor.permitted?(:view_client_contact_details)
    rows = ranked_rows
    Outcome.new(records: rows.first(LIMIT).map { |row| to_result(row) }, truncated: rows.size > LIMIT)
  end

  private

  def ensure_authorized!
    return if @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:view_client_directory)

    raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
  end

  def ranked_rows
    branches = ranked_branches
    return [] if branches.empty?

    union = branches.map { |sql| "(#{sql})" }.join(" UNION ALL ")
    display_sql = "coalesce(nullif(btrim(client_people.preferred_name), ''), client_people.first_name) || ' ' || client_people.last_name"
    sql = <<~SQL.squish
      SELECT client_people.id,
             client_people.first_name,
             client_people.preferred_name,
             client_people.last_name,
             client_people.status,
             clients.client_reference,
             MIN(matches.search_rank) AS search_rank
      FROM (#{union}) matches
      INNER JOIN client_people ON client_people.id = matches.person_id
      LEFT JOIN clients ON clients.client_person_id = client_people.id
      GROUP BY client_people.id, client_people.first_name, client_people.preferred_name,
               client_people.last_name, client_people.status, clients.client_reference
      ORDER BY MIN(matches.search_rank),
               CASE WHEN client_people.status = 'active' THEN 0 ELSE 1 END,
               #{display_sql},
               client_people.id
      LIMIT #{FETCH_LIMIT}
    SQL
    ClientPerson.find_by_sql(sql)
  end

  def ranked_branches
    branches = []
    branches << reference_branch if reference_query
    branches << email_branch if @can_see_contacts && email_query
    branches << phone_branch if @can_see_contacts && phone_digits.length >= 7
    branches << exact_name_branch if normalized_query.present?
    branches << prefix_name_branch if prefix_tsquery.present?
    branches << postal_branch if @can_see_contacts && normalized_query.present?
    branches.compact
  end

  def people
    scope = @agency.client_people.left_joins(:client)
    @status == "all" ? scope : scope.where(status: @status)
  end

  def reference_branch
    limited_branch(people.where(clients: { client_reference: reference_query }), 1)
  end

  def email_branch
    ids = ClientPersonEmailAddress.where(agency_id: @agency.id, normalized_address: email_query).select(:client_person_id)
    limited_branch(people.where(id: ids), 2)
  end

  def phone_branch
    digits = phone_digits
    ids = ClientPersonPhoneNumber.where(agency_id: @agency.id, normalized_number: "+#{digits}").or(
      ClientPersonPhoneNumber.where(agency_id: @agency.id).where(
        "phone_digits_reversed LIKE ?",
        "#{ClientPersonPhoneNumber.sanitize_sql_like(digits.reverse)}%"
      )
    ).select(:client_person_id)
    limited_branch(people.where(id: ids), 3)
  end

  def exact_name_branch
    limited_branch(people.where(name_search_key: normalized_query), 4)
  end

  def prefix_name_branch
    limited_branch(people.where("name_search_vector @@ to_tsquery('simple', ?)", prefix_tsquery), 5)
  end

  def postal_branch
    key = normalized_query
    ids = ClientPersonPostalAddress.where(agency_id: @agency.id, postal_code_search_key: key)
      .or(
        ClientPersonPostalAddress.where(agency_id: @agency.id).where(
          "locality_search_key LIKE ?",
          "#{ClientPersonPostalAddress.sanitize_sql_like(key)}%"
        )
      )
      .select(:client_person_id)
    limited_branch(people.where(id: ids), 6)
  end

  def limited_branch(scope, rank)
    display_sql = "coalesce(nullif(btrim(client_people.preferred_name), ''), client_people.first_name) || ' ' || client_people.last_name"
    scope
      .reorder(Arel.sql("CASE WHEN client_people.status = 'active' THEN 0 ELSE 1 END, #{display_sql}, client_people.id"))
      .limit(FETCH_LIMIT)
      .select("client_people.id AS person_id, #{rank.to_i} AS search_rank")
      .to_sql
  end

  def to_result(person)
    rank = person.read_attribute("search_rank").to_i
    Result.new(
      id: person.id,
      display_name: person.display_name,
      status: person.status,
      client_reference: person.read_attribute("client_reference"),
      rank: rank,
      kind: KINDS[rank]
    )
  end

  def reference_query
    reference = @query.strip.upcase
    reference if reference.match?(Client::REFERENCE_FORMAT)
  end

  def email_query
    email = @query.strip.downcase
    email if email.include?("@")
  end

  def phone_digits
    @query.gsub(/\D/, "")
  end

  def normalized_query
    @normalized_query ||= SearchNormalizer.normalize(@query)
  end

  def prefix_tsquery
    return @prefix_tsquery if defined?(@prefix_tsquery)

    tokens = SearchNormalizer.tokens(@query)
    @prefix_tsquery = if tokens.empty?
      nil
    else
      lexemes = tokens.map { |token| quoted_lexeme(token) }
      lexemes.any?(&:nil?) ? nil : lexemes.map { |lexeme| "#{lexeme}:*" }.join(" & ")
    end
  end

  def quoted_lexeme(token)
    return if token.match?(/[&|!():*<>\\']/) && !token.match?(/\A[[:alnum:]\-]+\z/)

    "'#{token.gsub("'", "''")}'"
  end
end
