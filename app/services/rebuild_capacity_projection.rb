class RebuildCapacityProjection < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, pool:, now: Time.current)
    @agency = agency
    @pool = pool
    @now = now
  end

  def call
    ActiveRecord::Base.transaction do
      lock_system_agency!
      pool = @agency.capacity_pools.lock.find(@pool.id)
      ensure_numeric_capacity_pool!(pool)
      projection = pool.capacity_projection || build_initial_capacity_projection(pool, @now)
      projection.lock! unless projection.new_record?

      events = pool.capacity_events.order(:effective_on, :effective_sequence, :recorded_at, :id).to_a
      CapacityTimelineReplay.new(events).call
      applied_events = events.select { |event| event.applies_at <= @now }
      current = applied_events.sum { |event| CapacityTimelineReplay::DIRECTIONS.fetch(event.event_type).sign * event.quantity }
      last_event = applied_events.last
      next_event = events.select { |event| event.applies_at > @now }.min_by do |event|
        [ event.applies_at, event.effective_on, event.effective_sequence, event.recorded_at, event.id ]
      end

      projection.update!(
        current_supplier_capacity: current,
        last_event: last_event,
        last_effective_on: last_event&.effective_on,
        last_effective_sequence: last_event&.effective_sequence,
        last_recorded_at: last_event&.recorded_at,
        next_event: next_event,
        next_applies_at: next_event&.applies_at,
        rebuilt_at: @now
      )
      AgencyCommand::Result.new(status: :updated, record: projection)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end
end
