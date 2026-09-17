class RefreshDueCapacityProjectionsJob < ApplicationJob
  queue_as :capacity

  BATCH_SIZE = 100

  def self.candidate_relation(at:, cursor: nil)
    relation = CapacityProjection
      .joins(:agency)
      .where(agencies: { status: "active" })
      .where("capacity_projections.next_applies_at <= ?", at)
    if cursor
      next_applies_at, capacity_pool_id = cursor
      relation = relation.where(
        "(capacity_projections.next_applies_at, capacity_projections.capacity_pool_id) > (?, ?)",
        next_applies_at,
        capacity_pool_id
      )
    end

    relation.order("capacity_projections.next_applies_at", "capacity_projections.capacity_pool_id").limit(BATCH_SIZE)
  end

  def perform
    observed_at = Time.current
    cursor = nil
    loop do
      rows = next_batch(cursor, at: observed_at)
      break if rows.empty?

      rows.each do |agency_id, capacity_pool_id, _next_applies_at|
        RefreshCapacityProjectionJob.perform_later(agency_id:, capacity_pool_id:)
      end
      break if rows.size < BATCH_SIZE

      last = rows.last
      cursor = [ last[2], last[1] ]
    end
  end

  private

  def next_batch(cursor, at:)
    self.class.candidate_relation(at:, cursor:).pluck(
      "capacity_projections.agency_id",
      "capacity_projections.capacity_pool_id",
      "capacity_projections.next_applies_at"
    )
  end
end
