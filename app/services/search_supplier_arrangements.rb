class SearchSupplierArrangements < AgencyCommand
  include DepartureCommandSupport

  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1
  STATUSES = (SupplierArrangement::STATUSES + [ "all" ]).freeze

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(
    agency:,
    actor:,
    query: nil,
    status: "all",
    contracting_supplier_id: nil,
    departure_id: nil,
    identifier_type: nil
  )
    @agency = agency
    @actor = actor
    @query = query.to_s
    @status = status.presence || "all"
    @contracting_supplier_id = contracting_supplier_id
    @departure_id = departure_id
    @identifier_type = identifier_type.to_s.strip.presence
  end

  def call
    ensure_directory_actor!(@actor, @agency, :view_departures)
    raise Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @query.length > 100
    raise Error.new("Choose a valid status.", code: :invalid) unless STATUSES.include?(@status)
    if @identifier_type.present? && !SupplierIssuedIdentifier::IDENTIFIER_TYPES.include?(@identifier_type)
      raise Error.new("Choose a valid identifier type.", code: :invalid)
    end

    rows = filtered.limit(FETCH_LIMIT).to_a
    Outcome.new(records: rows.first(LIMIT), truncated: rows.size > LIMIT)
  end

  private

  def filtered
    scope = @agency.supplier_arrangements
      .joins(:contracting_supplier, :departure)
      .preload(:contracting_supplier, :departure, :supplier_contact)
    scope = scope.where(status: @status) unless @status == "all"
    scope = apply_supplier_filter(scope)
    scope = apply_departure_filter(scope)
    scope = apply_identifier_type_filter(scope)
    apply_query(scope)
  end

  def apply_supplier_filter(scope)
    return scope if @contracting_supplier_id.blank?

    supplier = @agency.suppliers.find_by(id: parse_optional_uuid(@contracting_supplier_id, "Contracting supplier"))
    raise ActiveRecord::RecordNotFound if supplier.nil?

    scope.where(contracting_supplier_id: supplier.id)
  end

  def apply_departure_filter(scope)
    return scope if @departure_id.blank?

    departure = @agency.departures.find_by(id: parse_optional_uuid(@departure_id, "Departure"))
    raise ActiveRecord::RecordNotFound if departure.nil?

    scope.where(departure_id: departure.id)
  end

  def apply_identifier_type_filter(scope)
    return scope if @identifier_type.blank?

    scope.where(
      id: SupplierIssuedIdentifier.where(agency_id: @agency.id, identifier_type: @identifier_type, superseded_at: nil)
        .select(:supplier_arrangement_id)
    )
  end

  def apply_query(scope)
    stripped = @query.strip
    if stripped.blank?
      return scope.select("supplier_arrangements.*", Arel.sql("0 AS search_rank"))
        .order(Arel.sql(<<~SQL.squish))
          CASE supplier_arrangements.status WHEN 'active' THEN 0 WHEN 'draft' THEN 1 ELSE 2 END ASC,
          lower(supplier_arrangements.name) ASC,
          lower(coalesce(suppliers.doing_business_as, suppliers.display_name, suppliers.first_name || ' ' || suppliers.last_name)) ASC,
          departures.starts_on ASC NULLS LAST,
          supplier_arrangements.id ASC
        SQL
    end

    normalized = SearchNormalizer.normalize(stripped)
    like = "#{SupplierArrangement.sanitize_sql_like(normalized)}%"
    exact = normalized
    reference = stripped.upcase

    identifier_exact_ids = SupplierIssuedIdentifier.where(agency_id: @agency.id, superseded_at: nil)
      .where("normalized_value = ?", exact).select(:supplier_arrangement_id)
    reservation_identifier_ids = SupplierIssuedIdentifier.where(agency_id: @agency.id, superseded_at: nil)
      .where.not(supplier_reservation_id: nil)
      .where("normalized_value = ? OR normalized_value LIKE ?", exact, like)
      .select(:supplier_arrangement_id)

    scope = scope.where(
      "dd_search_normalize(supplier_arrangements.name) LIKE ? OR " \
      "dd_search_normalize(coalesce(suppliers.doing_business_as, suppliers.display_name, suppliers.first_name || ' ' || suppliers.last_name)) LIKE ? OR " \
      "coalesce(suppliers.supplier_reference, '') ILIKE ? OR " \
      "coalesce(departures.departure_reference, '') ILIKE ? OR " \
      "dd_search_normalize(departures.name) LIKE ? OR " \
      "supplier_arrangements.id IN (?) OR supplier_arrangements.id IN (?)",
      like, like, "#{SupplierArrangement.sanitize_sql_like(stripped)}%",
      "#{SupplierArrangement.sanitize_sql_like(reference)}%", like,
      identifier_exact_ids, reservation_identifier_ids
    )

    rank_sql = ActiveRecord::Base.sanitize_sql_array([ <<~SQL.squish, exact, exact, exact, like, like, like, like ])
      CASE
        WHEN EXISTS (
          SELECT 1 FROM supplier_issued_identifiers sii
          WHERE sii.agency_id = supplier_arrangements.agency_id
            AND sii.supplier_arrangement_id = supplier_arrangements.id
            AND sii.superseded_at IS NULL
            AND sii.normalized_value = ?
        ) THEN 1
        WHEN coalesce(suppliers.supplier_reference, '') ILIKE ? THEN 2
        WHEN dd_search_normalize(supplier_arrangements.name) = ? THEN 3
        WHEN dd_search_normalize(supplier_arrangements.name) LIKE ? THEN 4
        WHEN dd_search_normalize(coalesce(suppliers.doing_business_as, suppliers.display_name, suppliers.first_name || ' ' || suppliers.last_name)) LIKE ? THEN 5
        WHEN coalesce(departures.departure_reference, '') ILIKE ? OR dd_search_normalize(departures.name) LIKE ? THEN 6
        ELSE 7
      END
    SQL

    scope.select("supplier_arrangements.*", Arel.sql("#{rank_sql} AS search_rank"))
      .order(Arel.sql(<<~SQL.squish))
        search_rank ASC,
        CASE supplier_arrangements.status WHEN 'active' THEN 0 WHEN 'draft' THEN 1 ELSE 2 END ASC,
        lower(supplier_arrangements.name) ASC,
        lower(coalesce(suppliers.doing_business_as, suppliers.display_name, suppliers.first_name || ' ' || suppliers.last_name)) ASC,
        departures.starts_on ASC NULLS LAST,
        supplier_arrangements.id ASC
      SQL
  end
end
