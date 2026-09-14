class SearchClientDirectory
  Result = Data.define(:id, :display_name, :status, :client_reference, :client_status, :rank, :kind, :record_type)
  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1

  STATUSES = %w[active inactive all].freeze
  RECORD_KINDS = %w[all people organizations].freeze
  RANK_SELECT = {
    1 => Arel.sql("1 AS search_rank"),
    2 => Arel.sql("2 AS search_rank"),
    3 => Arel.sql("3 AS search_rank"),
    4 => Arel.sql("4 AS search_rank"),
    5 => Arel.sql("5 AS search_rank"),
    6 => Arel.sql("6 AS search_rank"),
    0 => Arel.sql("0 AS search_rank")
  }.freeze
  KINDS = {
    0 => nil,
    1 => "reference",
    2 => "email",
    3 => "phone",
    4 => "name",
    5 => "name_prefix",
    6 => "postal"
  }.freeze
  WEBSITE_KIND = "website"
  MATCH_KIND_SELECT = {
    nil => Arel.sql("NULL AS match_kind"),
    "reference" => Arel.sql("'reference' AS match_kind"),
    "email" => Arel.sql("'email' AS match_kind"),
    "phone" => Arel.sql("'phone' AS match_kind"),
    "name" => Arel.sql("'name' AS match_kind"),
    "name_prefix" => Arel.sql("'name_prefix' AS match_kind"),
    "postal" => Arel.sql("'postal' AS match_kind"),
    "website" => Arel.sql("'website' AS match_kind")
  }.freeze
  FINAL_ORDER = Arel.sql(<<~SQL.squish)
    MIN(matches.search_rank),
    CASE WHEN matches.status = 'active' THEN 0 ELSE 1 END,
    matches.display_name,
    CASE WHEN matches.record_type = 'person' THEN 0 ELSE 1 END,
    matches.record_id
  SQL

  def self.call(agency:, actor:, query: nil, status: "active", kind: "all")
    new(agency:, actor:, query:, status:, kind:).call
  end

  def initialize(agency:, actor:, query:, status:, kind:)
    @agency = agency
    @actor = actor
    @query = query.to_s
    @status = STATUSES.include?(status) ? status : "active"
    @kind = RECORD_KINDS.include?(kind) ? kind : "all"
  end

  def call
    ensure_authorized!
    raise AgencyCommand::Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @query.length > 100

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
    relations = ranked_branches
    return [] if relations.empty?

    union = relations.map(&:arel).reduce { |left, right| Arel::Nodes::UnionAll.new(left, right) }
    ClientPerson
      .from(Arel::Nodes::Grouping.new(union).as("matches"))
      .joins(<<~SQL.squish)
        LEFT JOIN clients ON (
          (matches.record_type = 'person' AND clients.client_person_id = matches.record_id)
          OR (matches.record_type = 'organization' AND clients.client_organization_id = matches.record_id)
        )
      SQL
      .select(
        "matches.record_id",
        "matches.record_type",
        "matches.display_name",
        "matches.status",
        "clients.client_reference",
        "clients.status AS client_status",
        "MIN(matches.search_rank) AS search_rank",
        "MIN(matches.match_kind) AS match_kind"
      )
      .group(
        "matches.record_id",
        "matches.record_type",
        "matches.display_name",
        "matches.status",
        "clients.client_reference",
        "clients.status"
      )
      .order(FINAL_ORDER)
      .limit(FETCH_LIMIT)
      .to_a
  end

  def ranked_branches
    return browse_branches if @query.blank?

    branches = []
    if include_people?
      branches << person_reference_branch if reference_query
      branches << person_email_branch if @can_see_contacts && email_query
      branches << person_phone_branch if @can_see_contacts && phone_digits.length >= 7
      branches << person_exact_name_branch if normalized_query.present?
      branches << person_prefix_name_branch if prefix_tsquery.present?
      branches << person_postal_branch if @can_see_contacts && normalized_query.present?
    end
    if include_organizations?
      branches << organization_reference_branch if reference_query
      branches << organization_email_branch if @can_see_contacts && email_query
      branches << organization_phone_branch if @can_see_contacts && phone_digits.length >= 7
      branches << organization_exact_name_branch if normalized_query.present?
      branches << organization_prefix_name_branch if prefix_tsquery.present?
      branches << organization_postal_branch if @can_see_contacts && normalized_query.present?
      branches << organization_website_branch if @can_see_contacts && normalized_query.present?
    end
    branches.compact
  end

  def browse_branches
    branches = []
    branches << person_browse_branch if include_people?
    branches << organization_browse_branch if include_organizations?
    branches
  end

  def include_people?
    @kind != "organizations"
  end

  def include_organizations?
    @kind != "people"
  end

  def people
    scope = @agency.client_people
    @status == "all" ? scope : scope.where(status: @status)
  end

  def organizations
    scope = @agency.client_organizations
    @status == "all" ? scope : scope.where(status: @status)
  end

  def person_browse_branch
    person_branch(people, 0)
  end

  def organization_browse_branch
    organization_branch(organizations, 0)
  end

  def person_reference_branch
    person_branch(people.joins(:client).where(clients: { client_reference: reference_query }), 1)
  end

  def organization_reference_branch
    organization_branch(organizations.joins(:client).where(clients: { client_reference: reference_query }), 1)
  end

  def person_email_branch
    ids = ClientPersonEmailAddress.where(agency_id: @agency.id, normalized_address: email_query).select(:client_person_id)
    person_branch(people.where(id: ids), 2)
  end

  def organization_email_branch
    ids = ClientOrganizationEmailAddress.where(agency_id: @agency.id, normalized_address: email_query).select(:client_organization_id)
    organization_branch(organizations.where(id: ids), 2)
  end

  def person_phone_branch
    person_branch(people.where(id: phone_person_ids), 3)
  end

  def organization_phone_branch
    organization_branch(organizations.where(id: phone_organization_ids), 3)
  end

  def person_exact_name_branch
    person_branch(people.where(name_search_key: normalized_query), 4)
  end

  def organization_exact_name_branch
    organization_branch(
      organizations.where(display_name_search_key: normalized_query)
        .or(organizations.where(legal_name_search_key: normalized_query)),
      4
    )
  end

  def person_prefix_name_branch
    person_branch(people.where("name_search_vector @@ to_tsquery('simple', ?)", prefix_tsquery), 5)
  end

  def organization_prefix_name_branch
    organization_branch(organizations.where("name_search_vector @@ to_tsquery('simple', ?)", prefix_tsquery), 5)
  end

  def person_postal_branch
    key = normalized_query
    ids = ClientPersonPostalAddress.where(agency_id: @agency.id, postal_code_search_key: key)
      .or(
        ClientPersonPostalAddress.where(agency_id: @agency.id).where(
          "locality_search_key LIKE ?",
          "#{ClientPersonPostalAddress.sanitize_sql_like(key)}%"
        )
      )
      .select(:client_person_id)
    person_branch(people.where(id: ids), 6)
  end

  def organization_postal_branch
    key = normalized_query
    ids = ClientOrganizationPostalAddress.where(agency_id: @agency.id, postal_code_search_key: key)
      .or(
        ClientOrganizationPostalAddress.where(agency_id: @agency.id).where(
          "locality_search_key LIKE ?",
          "#{ClientOrganizationPostalAddress.sanitize_sql_like(key)}%"
        )
      )
      .select(:client_organization_id)
    organization_branch(organizations.where(id: ids), 6)
  end

  def organization_website_branch
    key = normalized_query
    ids = ClientOrganizationWebsite.where(agency_id: @agency.id).where(
      "normalized_host = ? OR normalized_host LIKE ?",
      key,
      "#{ClientOrganizationWebsite.sanitize_sql_like(key)}%"
    ).select(:client_organization_id)
    organization_branch(organizations.where(id: ids), 6, match_kind: WEBSITE_KIND)
  end

  def phone_person_ids
    digits = phone_digits
    ClientPersonPhoneNumber.where(agency_id: @agency.id, normalized_number: "+#{digits}").or(
      ClientPersonPhoneNumber.where(agency_id: @agency.id).where(
        "phone_digits_reversed LIKE ?",
        "#{ClientPersonPhoneNumber.sanitize_sql_like(digits.reverse)}%"
      )
    ).select(:client_person_id)
  end

  def phone_organization_ids
    digits = phone_digits
    ClientOrganizationPhoneNumber.where(agency_id: @agency.id, normalized_number: "+#{digits}").or(
      ClientOrganizationPhoneNumber.where(agency_id: @agency.id).where(
        "phone_digits_reversed LIKE ?",
        "#{ClientOrganizationPhoneNumber.sanitize_sql_like(digits.reverse)}%"
      )
    ).select(:client_organization_id)
  end

  def person_branch(scope, rank, match_kind: KINDS.fetch(rank))
    display = <<~SQL.squish
      coalesce(nullif(btrim(client_people.preferred_name), ''), client_people.first_name) || ' ' || client_people.last_name
    SQL
    scope
      .reorder(Arel.sql("CASE WHEN client_people.status = 'active' THEN 0 ELSE 1 END, #{display}, client_people.id"))
      .limit(FETCH_LIMIT)
      .select(
        "client_people.id AS record_id",
        Arel.sql("'person' AS record_type"),
        Arel.sql("#{display} AS display_name"),
        "client_people.status AS status",
        RANK_SELECT.fetch(rank),
        MATCH_KIND_SELECT.fetch(match_kind)
      )
  end

  def organization_branch(scope, rank, match_kind: KINDS.fetch(rank))
    scope
      .reorder(Arel.sql("CASE WHEN client_organizations.status = 'active' THEN 0 ELSE 1 END, client_organizations.display_name, client_organizations.id"))
      .limit(FETCH_LIMIT)
      .select(
        "client_organizations.id AS record_id",
        Arel.sql("'organization' AS record_type"),
        "client_organizations.display_name AS display_name",
        "client_organizations.status AS status",
        RANK_SELECT.fetch(rank),
        MATCH_KIND_SELECT.fetch(match_kind)
      )
  end

  def to_result(row)
    rank = row.read_attribute("search_rank").to_i
    kind = row.read_attribute("match_kind").presence || KINDS[rank]
    Result.new(
      id: row.read_attribute("record_id"),
      display_name: row.read_attribute("display_name"),
      status: row.read_attribute("status"),
      client_reference: row.read_attribute("client_reference"),
      client_status: row.read_attribute("client_status"),
      rank: rank,
      kind: kind,
      record_type: row.read_attribute("record_type")
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
