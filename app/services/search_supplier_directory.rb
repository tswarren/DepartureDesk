class SearchSupplierDirectory
  Result = Data.define(
    :result_kind,
    :id,
    :display_name,
    :status,
    :rank,
    :match_kind,
    :supplier_id,
    :supplier_display_name,
    :supplier_reference,
    :supplier_kind,
    :category_codes
  )
  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1

  STATUSES = %w[active inactive all].freeze
  KINDS = %w[organization individual all].freeze
  RESULT_KINDS = {
    "supplier" => 0,
    "location" => 1,
    "contact" => 2
  }.freeze
  MATCH_KINDS = {
    0 => nil,
    1 => "reference",
    2 => "email",
    3 => "phone",
    4 => "name",
    5 => "name_prefix",
    6 => "category"
  }.freeze
  RANK_SELECT = {
    0 => Arel.sql("0 AS search_rank"),
    1 => Arel.sql("1 AS search_rank"),
    2 => Arel.sql("2 AS search_rank"),
    3 => Arel.sql("3 AS search_rank"),
    4 => Arel.sql("4 AS search_rank"),
    5 => Arel.sql("5 AS search_rank"),
    6 => Arel.sql("6 AS search_rank")
  }.freeze
  MATCH_KIND_SELECT = {
    nil => Arel.sql("NULL AS match_kind"),
    "reference" => Arel.sql("'reference' AS match_kind"),
    "email" => Arel.sql("'email' AS match_kind"),
    "phone" => Arel.sql("'phone' AS match_kind"),
    "name" => Arel.sql("'name' AS match_kind"),
    "name_prefix" => Arel.sql("'name_prefix' AS match_kind"),
    "category" => Arel.sql("'category' AS match_kind"),
    "postal" => Arel.sql("'postal' AS match_kind"),
    "website" => Arel.sql("'website' AS match_kind")
  }.freeze
  SUPPLIER_DISPLAY_SQL = "coalesce(suppliers.doing_business_as, suppliers.display_name, suppliers.first_name || ' ' || suppliers.last_name)".freeze
  FINAL_ORDER = Arel.sql(<<~SQL.squish)
    MIN(matches.search_rank),
    CASE WHEN matches.status = 'active' THEN 0 ELSE 1 END,
    matches.display_name,
    matches.supplier_kind,
    CASE matches.result_kind
      WHEN 'supplier' THEN 0
      WHEN 'location' THEN 1
      ELSE 2
    END,
    CASE
      WHEN matches.result_kind = 'supplier' THEN matches.record_id::text
      ELSE matches.supplier_reference
    END,
    matches.record_id
  SQL

  def self.call(agency:, actor:, query: nil, status: "active", kind: "all", category: "all")
    new(agency:, actor:, query:, status:, kind:, category:).call
  end

  def initialize(agency:, actor:, query:, status:, kind:, category:)
    @agency = agency
    @actor = actor
    @query = query.to_s
    @status = STATUSES.include?(status) ? status : "active"
    @kind = KINDS.include?(kind) ? kind : "all"
    @category = SupplierCategory::CODES.include?(category) ? category : "all"
  end

  def call
    ensure_authorized!
    raise AgencyCommand::Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @query.length > 100

    @can_see_contacts = @actor.permitted?(:view_supplier_contact_details)
    rows = ranked_rows
    Outcome.new(records: rows.first(LIMIT).map { |row| to_result(row) }, truncated: rows.size > LIMIT)
  end

  private

  def ensure_authorized!
    return if @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:view_supplier_directory)

    raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
  end

  def ranked_rows
    relations = ranked_branches
    return [] if relations.empty?

    union = relations.map(&:arel).reduce { |left, right| Arel::Nodes::UnionAll.new(left, right) }
    Supplier
      .from(Arel::Nodes::Grouping.new(union).as("matches"))
      .joins(<<~SQL.squish)
        LEFT JOIN supplier_category_assignments ON
          supplier_category_assignments.agency_id = #{Supplier.connection.quote(@agency.id)}
          AND supplier_category_assignments.supplier_id = matches.supplier_id
      SQL
      .select(
        "matches.result_kind",
        "matches.record_id",
        "matches.display_name",
        "matches.status",
        "matches.supplier_id",
        "matches.supplier_display_name",
        "matches.supplier_reference",
        "matches.supplier_kind",
        "MIN(matches.search_rank) AS search_rank",
        "(array_agg(matches.match_kind ORDER BY matches.search_rank ASC, matches.match_kind ASC NULLS LAST))[1] AS match_kind",
        "array_remove(array_agg(DISTINCT supplier_category_assignments.category_code ORDER BY supplier_category_assignments.category_code), NULL) AS category_codes"
      )
      .group(
        "matches.result_kind",
        "matches.record_id",
        "matches.display_name",
        "matches.status",
        "matches.supplier_id",
        "matches.supplier_display_name",
        "matches.supplier_reference",
        "matches.supplier_kind"
      )
      .order(FINAL_ORDER)
      .limit(FETCH_LIMIT)
      .to_a
  end

  def ranked_branches
    return [ supplier_branch(suppliers_for_results, 0) ] if @query.blank?

    branches = []
    branches << supplier_reference_branch if reference_query
    if @can_see_contacts && email_query
      branches << supplier_email_branch
      branches << contact_email_branch
    end
    if @can_see_contacts && phone_digits.length >= 7
      branches << supplier_phone_branch
      branches << contact_phone_branch
    end
    if normalized_query.present?
      branches << supplier_exact_name_branch
      branches << location_exact_name_branch
      branches << contact_exact_name_branch if @can_see_contacts
    end
    if prefix_tsquery.present?
      branches << supplier_prefix_name_branch
      branches << location_prefix_name_branch
      branches << contact_prefix_name_branch if @can_see_contacts
    end
    branches << supplier_category_branch if category_query_codes.any?
    if @can_see_contacts && normalized_query.present?
      branches << supplier_postal_branch
      branches << location_postal_branch
      branches << supplier_website_branch
    elsif normalized_query.present?
      # Viewer may not match Location postal fields.
    end
    branches.compact
  end

  def filtered_suppliers
    scope = @agency.suppliers
    scope = scope.where(kind: @kind) unless @kind == "all"
    scope = scope.where(id: SupplierCategoryAssignment.where(agency_id: @agency.id, category_code: @category).select(:supplier_id)) unless @category == "all"
    scope
  end

  def suppliers_for_results
    scope = filtered_suppliers
    scope = scope.where(status: @status) unless @status == "all"
    scope
  end

  def owning_suppliers
    filtered_suppliers
  end

  def location_scope
    scope = SupplierLocation.where(agency_id: @agency.id, supplier_id: owning_suppliers.select(:id))
    scope = scope.where(status: @status) unless @status == "all"
    scope
  end

  def contact_scope
    scope = SupplierContact.where(agency_id: @agency.id, supplier_id: owning_suppliers.select(:id))
    scope = scope.where(status: @status) unless @status == "all"
    scope
  end

  def supplier_reference_branch
    supplier_branch(suppliers_for_results.where(supplier_reference: reference_query), 1)
  end

  def supplier_email_branch
    ids = SupplierEmailAddress.where(agency_id: @agency.id, normalized_address: email_query).select(:supplier_id)
    supplier_branch(suppliers_for_results.where(id: ids), 2)
  end

  def contact_email_branch
    ids = SupplierContactEmailAddress.where(agency_id: @agency.id, normalized_address: email_query).select(:supplier_contact_id)
    contact_branch(contact_scope.where(id: ids), 2, match_kind: "email")
  end

  def supplier_phone_branch
    digits = phone_digits
    ids = SupplierPhoneNumber.where(agency_id: @agency.id, normalized_number: "+#{digits}").or(
      SupplierPhoneNumber.where(agency_id: @agency.id).where(
        "phone_digits_reversed LIKE ?",
        "#{SupplierPhoneNumber.sanitize_sql_like(digits.reverse)}%"
      )
    ).select(:supplier_id)
    supplier_branch(suppliers_for_results.where(id: ids), 3)
  end

  def contact_phone_branch
    digits = phone_digits
    ids = SupplierContactPhoneNumber.where(agency_id: @agency.id, normalized_number: "+#{digits}").or(
      SupplierContactPhoneNumber.where(agency_id: @agency.id).where(
        "phone_digits_reversed LIKE ?",
        "#{SupplierContactPhoneNumber.sanitize_sql_like(digits.reverse)}%"
      )
    ).select(:supplier_contact_id)
    contact_branch(contact_scope.where(id: ids), 3, match_kind: "phone")
  end

  def supplier_exact_name_branch
    key = normalized_query
    supplier_branch(
      suppliers_for_results.where(display_name_search_key: key)
        .or(suppliers_for_results.where(legal_name_search_key: key))
        .or(suppliers_for_results.where(doing_business_as_search_key: key))
        .or(suppliers_for_results.where(individual_full_name_search_key: key)),
      4
    )
  end

  def location_exact_name_branch
    location_branch(location_scope.where(name_search_key: normalized_query), 4)
  end

  def contact_exact_name_branch
    contact_branch(contact_scope.where(full_name_search_key: normalized_query), 4)
  end

  def supplier_prefix_name_branch
    supplier_branch(suppliers_for_results.where("suppliers.name_search_vector @@ to_tsquery('simple', ?)", prefix_tsquery), 5)
  end

  def location_prefix_name_branch
    return if prefix_tsquery.blank?

    location_branch(
      location_scope.where("supplier_locations.name_search_vector @@ to_tsquery('simple', ?)", prefix_tsquery),
      5,
      match_kind: "name_prefix"
    )
  end

  def contact_prefix_name_branch
    contact_branch(
      contact_scope.where("supplier_contacts.name_search_vector @@ to_tsquery('simple', ?)", prefix_tsquery),
      5,
      match_kind: "name_prefix"
    )
  end

  def supplier_category_branch
    ids = SupplierCategoryAssignment.where(agency_id: @agency.id, category_code: category_query_codes).select(:supplier_id)
    supplier_branch(suppliers_for_results.where(id: ids), 6)
  end

  def supplier_postal_branch
    key = normalized_query
    ids = SupplierPostalAddress.where(agency_id: @agency.id, postal_code_search_key: key)
      .or(
        SupplierPostalAddress.where(agency_id: @agency.id).where(
          "locality_search_key LIKE ?",
          "#{SupplierPostalAddress.sanitize_sql_like(key)}%"
        )
      )
      .select(:supplier_id)
    supplier_branch(suppliers_for_results.where(id: ids), 6, match_kind: "postal")
  end

  def location_postal_branch
    key = normalized_query
    scope = location_scope.where(postal_code_search_key: key).or(
      location_scope.where("locality_search_key LIKE ?", "#{SupplierLocation.sanitize_sql_like(key)}%")
    )
    location_branch(scope, 6, match_kind: "postal")
  end

  def supplier_website_branch
    key = normalized_query
    ids = SupplierWebsite.where(agency_id: @agency.id).where(
      "normalized_host = ? OR normalized_host LIKE ?",
      key,
      "#{SupplierWebsite.sanitize_sql_like(key)}%"
    ).select(:supplier_id)
    supplier_branch(suppliers_for_results.where(id: ids), 6, match_kind: "website")
  end

  def supplier_branch(scope, rank, match_kind: MATCH_KINDS.fetch(rank))
    scope
      .reorder(Arel.sql("CASE WHEN suppliers.status = 'active' THEN 0 ELSE 1 END, #{SUPPLIER_DISPLAY_SQL}, suppliers.kind, suppliers.id"))
      .limit(FETCH_LIMIT)
      .select(
        Arel.sql("'supplier' AS result_kind"),
        "suppliers.id AS record_id",
        Arel.sql("#{SUPPLIER_DISPLAY_SQL} AS display_name"),
        "suppliers.status AS status",
        "suppliers.id AS supplier_id",
        Arel.sql("#{SUPPLIER_DISPLAY_SQL} AS supplier_display_name"),
        "suppliers.supplier_reference AS supplier_reference",
        "suppliers.kind AS supplier_kind",
        RANK_SELECT.fetch(rank),
        MATCH_KIND_SELECT.fetch(match_kind)
      )
  end

  def location_branch(scope, rank, match_kind: MATCH_KINDS.fetch(rank))
    scope
      .joins("INNER JOIN suppliers ON suppliers.id = supplier_locations.supplier_id AND suppliers.agency_id = supplier_locations.agency_id")
      .reorder(Arel.sql("CASE WHEN supplier_locations.status = 'active' THEN 0 ELSE 1 END, supplier_locations.name, suppliers.kind, suppliers.supplier_reference, supplier_locations.id"))
      .select(
        Arel.sql("'location' AS result_kind"),
        "supplier_locations.id AS record_id",
        "supplier_locations.name AS display_name",
        "supplier_locations.status AS status",
        "suppliers.id AS supplier_id",
        Arel.sql("#{SUPPLIER_DISPLAY_SQL} AS supplier_display_name"),
        "suppliers.supplier_reference AS supplier_reference",
        "suppliers.kind AS supplier_kind",
        RANK_SELECT.fetch(rank),
        MATCH_KIND_SELECT.fetch(match_kind)
      )
  end

  def contact_branch(scope, rank, match_kind: MATCH_KINDS.fetch(rank))
    return unless @can_see_contacts

    scope
      .joins("INNER JOIN suppliers ON suppliers.id = supplier_contacts.supplier_id AND suppliers.agency_id = supplier_contacts.agency_id")
      .reorder(Arel.sql("CASE WHEN supplier_contacts.status = 'active' THEN 0 ELSE 1 END, supplier_contacts.first_name || ' ' || supplier_contacts.last_name, suppliers.kind, suppliers.supplier_reference, supplier_contacts.id"))
      .select(
        Arel.sql("'contact' AS result_kind"),
        "supplier_contacts.id AS record_id",
        Arel.sql("supplier_contacts.first_name || ' ' || supplier_contacts.last_name AS display_name"),
        "supplier_contacts.status AS status",
        "suppliers.id AS supplier_id",
        Arel.sql("#{SUPPLIER_DISPLAY_SQL} AS supplier_display_name"),
        "suppliers.supplier_reference AS supplier_reference",
        "suppliers.kind AS supplier_kind",
        RANK_SELECT.fetch(rank),
        MATCH_KIND_SELECT.fetch(match_kind)
      )
  end

  def to_result(row)
    rank = row.read_attribute("search_rank").to_i
    Result.new(
      result_kind: row.read_attribute("result_kind"),
      id: row.read_attribute("record_id"),
      display_name: row.read_attribute("display_name"),
      status: row.read_attribute("status"),
      rank: rank,
      match_kind: row.read_attribute("match_kind").presence || MATCH_KINDS[rank],
      supplier_id: row.read_attribute("supplier_id"),
      supplier_display_name: row.read_attribute("supplier_display_name"),
      supplier_reference: row.read_attribute("supplier_reference"),
      supplier_kind: row.read_attribute("supplier_kind"),
      category_codes: row.read_attribute("category_codes")
    )
  end

  def reference_query
    reference = @query.strip.upcase
    reference if reference.match?(Supplier::REFERENCE_FORMAT)
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

  def category_query_codes
    @category_query_codes ||= SupplierCategory::LABELS.filter_map do |code, label|
      code if SearchNormalizer.normalize(code) == normalized_query || SearchNormalizer.normalize(label).start_with?(normalized_query)
    end
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
