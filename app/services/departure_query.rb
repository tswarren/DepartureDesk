class DepartureQuery
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
end
