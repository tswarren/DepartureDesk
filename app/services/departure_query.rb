class DepartureQuery
  ProgramUpcomingSummary = Struct.new(:upcoming_count, :next_start_date, keyword_init: true)

  def initialize(agency:, membership:)
    @agency = agency
    @membership = membership
  end

  def relation
    scope = @agency.departures
    return scope if @membership.administrator?

    scope.where(office_id: @membership.accessible_offices.select(:id))
  end

  def for_program(program)
    relation.where(travel_program_id: program.id)
  end

  def upcoming_for_program(program, on:)
    for_program(program).nonterminal.where(start_date: on..).order(:start_date, :departure_reference)
  end

  def upcoming_program_summaries(program_ids:, on:)
    ids = Array(program_ids).compact.uniq
    return {} if ids.empty?

    rows = relation
      .nonterminal
      .where(travel_program_id: ids, start_date: on..)
      .group(:travel_program_id)
      .pluck(
        :travel_program_id,
        Arel.sql("COUNT(*)"),
        Arel.sql("MIN(start_date)")
      )

    rows.to_h do |travel_program_id, upcoming_count, next_start_date|
      [
        travel_program_id,
        ProgramUpcomingSummary.new(upcoming_count:, next_start_date:)
      ]
    end
  end
end
