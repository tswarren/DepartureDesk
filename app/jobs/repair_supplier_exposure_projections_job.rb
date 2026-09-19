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
    arrangements = agency.supplier_arrangements
      .where(status: "active")
      .order(:id)
      .limit(BATCH_SIZE)
    arrangements.each do |arrangement|
      RepairSupplierExposureProjectionJob.perform_later(
        agency_id: agency.id,
        supplier_arrangement_id: arrangement.id
      )
    end
  end
end
