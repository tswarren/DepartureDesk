# frozen_string_literal: true

# Rebuilds one Arrangement exposure projection. Creates no domain events.
class RepairSupplierExposureProjectionJob < ApplicationJob
  queue_as :exposure

  def perform(agency_id:, supplier_arrangement_id:)
    agency = Agency.find_by(id: agency_id)
    return if agency.nil? || !agency.active?

    arrangement = agency.supplier_arrangements.find_by(id: supplier_arrangement_id)
    return if arrangement.nil? || !arrangement.active?
    return if arrangement.governing_version_id.blank?

    ActiveRecord::Base.transaction do
      locked_agency = Agency.lock.find(agency.id)
      next unless locked_agency.active?

      locked = locked_agency.supplier_arrangements.lock.find_by(id: arrangement.id)
      next if locked.nil? || !locked.active?

      locked_agency.departures.lock.find(locked.departure_id)
      RebuildSupplierExposureProjectionAlreadyLocked.new(
        agency: locked_agency,
        arrangement: locked
      ).call
      RebuildSupplierAttentionProjectionAlreadyLocked.new(
        agency: locked_agency,
        arrangement: locked
      ).call
    end
  end
end
