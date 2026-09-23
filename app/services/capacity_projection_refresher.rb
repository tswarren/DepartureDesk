# frozen_string_literal: true

# Rebuilds CapacityProjection current/next pointers from the Pool event ledger.
# Shared by Staff capacity commands and deposit retained-quantity evaluation.
class CapacityProjectionRefresher
  def self.call(pool:, projection:, now: Time.current)
    new(pool:, projection:, now:).call
  end

  def initialize(pool:, projection:, now:)
    @pool = pool
    @projection = projection
    @now = now
  end

  def call
    events = @pool.capacity_events.order(:effective_on, :effective_sequence, :recorded_at, :id).to_a
    CapacityTimelineReplay.new(events).call

    applied_events = events.select { |event| event.applies_at <= @now }
    current = applied_events.sum do |event|
      CapacityTimelineReplay::DIRECTIONS.fetch(event.event_type).sign * event.quantity
    end
    last_event = applied_events.last
    next_event = events.select { |event| event.applies_at > @now }.min_by do |event|
      [ event.applies_at, event.effective_on, event.effective_sequence, event.recorded_at, event.id ]
    end

    attrs = {
      current_supplier_capacity: current,
      last_event: last_event,
      last_effective_on: last_event&.effective_on,
      last_effective_sequence: last_event&.effective_sequence,
      last_recorded_at: last_event&.recorded_at,
      next_event: next_event,
      next_applies_at: next_event&.applies_at
    }
    return @projection if matches?(@projection, attrs)

    @projection.update!(attrs.merge(rebuilt_at: @now))
    @projection
  end

  private

  def matches?(projection, attrs)
    attrs.all? do |name, value|
      if value.is_a?(ApplicationRecord)
        projection.public_send("#{name}_id") == value.id
      else
        projection.public_send(name) == value
      end
    end
  end
end
