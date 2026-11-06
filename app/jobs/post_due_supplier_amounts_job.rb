# Hourly sweep (SMN-05): enqueues one child job per confirmed arrangement
# that has schedule lines. Reads the primary database and enqueues into the
# queue database with no spanning transaction; delivery is at least once,
# and posting is idempotent.
class PostDueSupplierAmountsJob < ApplicationJob
  queue_as :supplier_money

  def perform
    SupplierArrangement.where(status: "confirmed").where(id: ScheduleLine.select(:supplier_arrangement_id))
      .pluck(:agency_id, :id).each do |agency_id, arrangement_id|
      PostArrangementAmountsDueJob.perform_later(agency_id:, arrangement_id:)
    end
  end
end
