class SearchDepartures
  include DepartureCommandSupport

  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1
  STATUSES = (Departure::SUMMARY_LABELS.keys + %w[all]).freeze
  DEFAULT_ORDER = Arel.sql("search_rank ASC, starts_on ASC NULLS LAST, name_search_key ASC, id ASC").freeze

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def self.composed_relation(**kwargs)
    new(**kwargs).composed_relation
  end

  def initialize(agency:, actor:, query: nil, status: "all", team_member_id: nil, starts_on_from: nil, starts_on_to: nil, ends_on_from: nil, ends_on_to: nil)
    @agency = agency
    @actor = actor
    @query = query.to_s
    @status = status.presence || "all"
    @team_member_id = team_member_id
    @starts_on_from = starts_on_from
    @starts_on_to = starts_on_to
    @ends_on_from = ends_on_from
    @ends_on_to = ends_on_to
  end

  def call
    rows = composed_relation.to_a
    Outcome.new(records: rows.first(LIMIT), truncated: rows.size > LIMIT)
  end

  def composed_relation
    ensure_authorized!
    raise AgencyCommand::Error.new("Enter a search of 100 characters or fewer.", code: :invalid) if @query.length > 100
    raise AgencyCommand::Error.new("Choose a valid status.", code: :invalid) unless STATUSES.include?(@status.to_s)

    filtered.limit(FETCH_LIMIT)
  end

  private

  def ensure_authorized!
    return if @actor&.active? && @actor.agency_id == @agency&.id && @actor.permitted?(:view_departures)

    raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
  end

  def filtered
    scope = @agency.departures.preload(team_members: :agency_user)
    scope = scope.with_summary_label(@status) unless @status == "all"
    member = resolve_filter_member
    if member
      scope = scope.where(id: @agency.departure_team_members.where(agency_user_id: member.id).select(:departure_id))
    end
    apply_date_filters(apply_query(scope))
  end

  def resolve_filter_member
    return if @team_member_id.blank?

    resolve_agency_user!(@team_member_id)
  end

  def apply_date_filters(scope)
    starts_from = parse_date(@starts_on_from, "Starts on from")
    starts_to = parse_date(@starts_on_to, "Starts on to")
    ends_from = parse_date(@ends_on_from, "Ends on from")
    ends_to = parse_date(@ends_on_to, "Ends on to")
    ensure_range!(starts_from, starts_to, "start")
    ensure_range!(ends_from, ends_to, "end")
    scope = scope.where("starts_on >= ?", starts_from) if starts_from
    scope = scope.where("starts_on <= ?", starts_to) if starts_to
    scope = scope.where("ends_on >= ?", ends_from) if ends_from
    scope = scope.where("ends_on <= ?", ends_to) if ends_to
    scope
  end

  def ensure_range!(from, to, label)
    return if from.blank? || to.blank? || from <= to

    raise AgencyCommand::Error.new("The #{label} date range is reversed.", code: :invalid)
  end

  def apply_query(scope)
    stripped = @query.strip
    if stripped.blank?
      return scope.select("departures.*", Arel.sql("0 AS search_rank")).order(DEFAULT_ORDER)
    end

    reference = stripped.upcase
    exact_name = SearchNormalizer.normalize(stripped)
    prefix = exact_name.present? ? "#{Departure.sanitize_sql_like(exact_name)}%" : ""
    rank_sql = ActiveRecord::Base.sanitize_sql_array([
      <<~SQL.squish,
        CASE
          WHEN departures.departure_reference = ? THEN 1
          WHEN ? <> '' AND departures.name_search_key = ? THEN 2
          WHEN ? <> '' AND departures.name_search_key LIKE ? THEN 3
        END AS search_rank
      SQL
      reference,
      exact_name,
      exact_name,
      prefix,
      prefix
    ])
    matched = scope.where(
      "departures.departure_reference = :reference OR (:exact_name <> '' AND departures.name_search_key = :exact_name) OR (:prefix <> '' AND departures.name_search_key LIKE :prefix)",
      reference:,
      exact_name:,
      prefix:
    )
    matched.select("departures.*", Arel.sql(rank_sql)).order(DEFAULT_ORDER)
  end
end
