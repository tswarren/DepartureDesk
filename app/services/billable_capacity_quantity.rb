# frozen_string_literal: true

# Opt-in billable quantity for a capacity-backed unit rate.
# Established and increased events count. Releases and withdrawals do not.
class BillableCapacityQuantity
  BILLABLE_EVENT_TYPES = %w[established increased].freeze

  def self.current(pool:, version:)
    return opening_quantity(pool, version) if version.draft?

    events = billable_events(pool)
    events.sum do |event|
      today = Time.current.in_time_zone(event.effective_time_zone).to_date
      event.effective_on <= today ? event.quantity : 0
    end
  end

  def self.quantity_at(pool:, version:, due_on:)
    return opening_quantity(pool, version) if version.draft?

    billable_events(pool).sum do |event|
      event.effective_on <= due_on ? event.quantity : 0
    end
  end

  def self.opening_quantity(pool, version)
    version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id).proposed_opening_quantity
  end

  def self.billable_events(pool)
    pool.capacity_events.where(event_type: BILLABLE_EVENT_TYPES).order(:effective_on, :effective_sequence, :recorded_at, :id).to_a
  end

  def self.confirmed_for_ceiling(pool:, version:)
    if version.draft? || pool.capacity_projection.nil?
      return opening_quantity(pool, version).to_i
    end

    current = pool.capacity_projection.current_supplier_capacity.to_i
    pending = pool.capacity_events.where(event_type: "increased").to_a.sum do |event|
      today = Time.current.in_time_zone(event.effective_time_zone).to_date
      event.effective_on > today ? event.quantity : 0
    end
    current + pending
  end
end
