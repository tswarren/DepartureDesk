class DepartureSelector
  def initialize(relation:, q: nil, status: nil, office_id: nil, from: nil, to: nil)
    @relation = relation
    @q = q.to_s.strip.presence
    @status = status
    @office_id = office_id
    @from = from
    @to = to
  end

  def relation
    scope = @relation.includes(:office, :travel_program, team_assignments: { agency_membership: { person_party: :party } })
    scope = scope.where(status: @status) if Departure::STATUSES.include?(@status)
    scope = scope.where(office_id: @office_id) if @office_id.present?
    scope = scope.where(start_date: @from..) if @from.present?
    scope = scope.where(end_date: ..@to) if @to.present?
    scope = apply_query(scope) if @q
    scope.order(:start_date, :departure_reference)
  end

  private

  def apply_query(scope)
    pattern = "%#{sanitize_like(@q)}%"
    scope.left_joins(:travel_program).where(
      <<~SQL.squish,
        departures.departure_reference ILIKE :pattern
        OR departures.name ILIKE :pattern
        OR COALESCE(departures.primary_destination, '') ILIKE :pattern
        OR COALESCE(travel_programs.name, '') ILIKE :pattern
        OR departures.departure_reference % :q
        OR departures.name % :q
      SQL
      pattern:,
      q: @q
    )
  end

  def sanitize_like(value)
    ActiveRecord::Base.sanitize_sql_like(value)
  end
end
