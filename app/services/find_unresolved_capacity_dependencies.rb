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

    pools = scoped(@agency.capacity_pools).includes(:capacity_events).order(:id).to_a
    nonzero_ids = []
    pending_events = []

    pools.each do |pool|
      next unless pool.numeric_inventory?

      events = pool.capacity_events.sort_by do |event|
        [ event.effective_on, event.effective_sequence, event.recorded_at, event.id ]
      end
      next if events.empty?

      CapacityTimelineReplay.new(events).call
      applied = events.select { |event| event.applies_at <= @now }
      pending = events.select { |event| event.applies_at > @now }
      current = applied.sum { |event| CapacityTimelineReplay::DIRECTIONS.fetch(event.event_type).sign * event.quantity }
      nonzero_ids << pool.id if current.positive?
      pending_events.concat(pending)
    end

    Result.new(
      capacity_pool_ids: nonzero_ids,
      pending_capacity_event_ids: pending_events
        .sort_by { |event| [ event.applies_at, event.capacity_pool_id, event.id ] }
        .map(&:id),
      open_capacity_reconciliation_ids: open_capacity_reconciliation_ids
    )
  end

  private

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
