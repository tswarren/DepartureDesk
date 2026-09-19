# frozen_string_literal: true

class RefreshDueDeadlineProjectionsJob < ApplicationJob
  queue_as :deadlines

  BATCH_SIZE = 100

  def self.candidate_relation(at:, cursor: nil)
    relation = SupplierDeadlineProjection
      .joins(:agency)
      .where(agencies: { status: "active" })
      .where("supplier_deadline_projections.next_transition_at <= ?", at)
    if cursor
      next_transition_at, id = cursor
      relation = relation.where(
        "(supplier_deadline_projections.next_transition_at, supplier_deadline_projections.id) > (?, ?)",
        next_transition_at,
        id
      )
    end

    relation.order(
      "supplier_deadline_projections.next_transition_at",
      "supplier_deadline_projections.id"
    ).limit(BATCH_SIZE)
  end

  def perform
    observed_at = Time.current
    cursor = nil
    loop do
      rows = next_batch(cursor, at: observed_at)
      break if rows.empty?

      rows.each do |agency_id, occurrence_id, _next_transition_at|
        RefreshDeadlineProjectionJob.perform_later(
          agency_id:,
          supplier_deadline_occurrence_id: occurrence_id
        )
      end
      break if rows.size < BATCH_SIZE

      last = rows.last
      cursor = [ last[2], last[3] ]
    end
  end

  private

  def next_batch(cursor, at:)
    self.class.candidate_relation(at:, cursor:).pluck(
      "supplier_deadline_projections.agency_id",
      "supplier_deadline_projections.supplier_deadline_occurrence_id",
      "supplier_deadline_projections.next_transition_at",
      "supplier_deadline_projections.id"
    )
  end
end
