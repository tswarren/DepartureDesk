class ListDepartureArrangements < AgencyCommand
  include DepartureCommandSupport

  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1
  STATUSES = (SupplierArrangement::STATUSES + [ "all" ]).freeze
  DEFAULT_ORDER = Arel.sql(
    "lower(coalesce(suppliers.doing_business_as, suppliers.display_name, suppliers.first_name || ' ' || suppliers.last_name)) ASC, supplier_arrangements.name ASC, supplier_arrangements.id ASC"
  ).freeze

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(agency:, actor:, departure:, q: nil, status: "all", contracting_supplier_id: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @q = q.to_s
    @status = status.presence || "all"
    @contracting_supplier_id = contracting_supplier_id
  end

  def call
    ensure_directory_actor!(@actor, @agency, :view_departures)
    raise Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @q.length > 100
    raise Error.new("Choose a valid status.", code: :invalid) unless STATUSES.include?(@status)

    departure = @agency.departures.find(@departure.id)
    scope = departure.supplier_arrangements
      .joins(:contracting_supplier)
      .preload(:contracting_supplier, :supplier_contact, :versions)
    scope = scope.where(status: @status) unless @status == "all"
    scope = apply_contractor_filter(scope)
    scope = apply_query(scope)
    rows = scope.order(DEFAULT_ORDER).limit(FETCH_LIMIT).to_a
    Outcome.new(records: rows.first(LIMIT), truncated: rows.size > LIMIT)
  end

  private

  def apply_contractor_filter(scope)
    return scope if @contracting_supplier_id.blank?

    supplier_id = parse_optional_uuid(@contracting_supplier_id, "Contracting supplier")
    supplier = @agency.suppliers.find_by(id: supplier_id)
    raise ActiveRecord::RecordNotFound if supplier.nil?

    scope.where(contracting_supplier_id: supplier.id)
  end

  def apply_query(scope)
    normalized = SearchNormalizer.normalize(@q)
    return scope if normalized.blank?

    scope.where("dd_search_normalize(supplier_arrangements.name) LIKE ?", "#{SupplierArrangement.sanitize_sql_like(normalized)}%")
  end
end
