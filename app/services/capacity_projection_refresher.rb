# frozen_string_literal: true

# Restored from tag pre-m3-m4-deletion (ADR 0018 spike amendment), keyed to
# the inventory group instead of a versioned pool. Rebuilds the projection's
# current and next pointers from the group's event ledger.
class CapacityProjectionRefresher
  def self.call(group:, projection:, now: Clock.current.now)
    new(group:, projection:, now:).call
  end

  def initialize(group:, projection:, now:)
    @group = group
    @projection = projection
    @now = now
  end

  def call
    events = @group.capacity_events.order(:effective_on, :effective_sequence, :recorded_at, :id).to_a
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
