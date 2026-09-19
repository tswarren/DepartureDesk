# frozen_string_literal: true

# Bounded Agency repair sweep for exposure projection drift.
# Not part of ordinary correctness; consequential commands rebuild synchronously.
class RepairSupplierExposureProjectionsJob < ApplicationJob
  queue_as :exposure

  BATCH_SIZE = 50

  def perform(agency_id: nil)
    scope = Agency.where(status: "active")
    scope = scope.where(id: agency_id) if agency_id.present?
    scope.order(:id).find_each do |agency|
      repair_agency!(agency)
    end
  end

  private

  def repair_agency!(agency)
    cursor = nil
    loop do
      relation = agency.supplier_arrangements.where(status: "active").order(:id)
      relation = relation.where("id > ?", cursor) if cursor
      batch = relation.limit(BATCH_SIZE).to_a
      break if batch.empty?

      batch.each do |arrangement|
        RepairSupplierExposureProjectionJob.perform_later(
          agency_id: agency.id,
          supplier_arrangement_id: arrangement.id
        )
      end
      break if batch.size < BATCH_SIZE

      cursor = batch.last.id
    end
  end
end
