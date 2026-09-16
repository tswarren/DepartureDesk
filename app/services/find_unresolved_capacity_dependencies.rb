class FindUnresolvedCapacityDependencies
  Result = Data.define(:capacity_pool_ids, :pending_capacity_event_ids, :open_capacity_reconciliation_ids)

  def initialize(agency:, arrangement: nil, departure: nil, now: Time.current)
    @agency = agency
    @arrangement = arrangement
    @departure = departure
    @now = now
  end

  def call
    raise ArgumentError, "Provide an arrangement or departure scope." if @arrangement.nil? && @departure.nil?

    Result.new(
      capacity_pool_ids: nonzero_capacity_pool_ids,
      pending_capacity_event_ids: pending_capacity_event_ids,
      open_capacity_reconciliation_ids: open_capacity_reconciliation_ids
    )
  end

  private

  def nonzero_capacity_pool_ids
    scoped(@agency.capacity_projections)
      .where.not(current_supplier_capacity: 0)
      .order(:capacity_pool_id)
      .pluck(:capacity_pool_id)
  end

  def pending_capacity_event_ids
    scoped(@agency.capacity_events)
      .where("applies_at > ?", @now)
      .order(:applies_at, :capacity_pool_id, :id)
      .pluck(:id)
  end

  def open_capacity_reconciliation_ids
    scoped(@agency.capacity_reconciliations)
      .where.not(variance: 0)
      .includes(resolutions: :capacity_event)
      .order(:capacity_pool_id, :id)
      .select(&:open_discrepancy?)
      .map(&:id)
  end

  def scoped(relation)
    relation = relation.where(departure_id: @departure.id) if @departure
    relation = relation.where(supplier_arrangement_id: @arrangement.id) if @arrangement
    relation
  end
end
