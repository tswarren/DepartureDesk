# frozen_string_literal: true

class RefreshDeadlineProjectionJob < ApplicationJob
  queue_as :deadlines

  def perform(agency_id:, supplier_deadline_occurrence_id:)
    agency = Agency.find_by(id: agency_id)
    return if agency.nil? || !agency.active?

    occurrence = SupplierDeadlineOccurrence.find_by(
      id: supplier_deadline_occurrence_id, agency_id: agency.id
    )
    return if occurrence.nil? || occurrence.superseded_at.present?

    ActiveRecord::Base.transaction do
      # Canonical M3E order: Agency → Departure → Arrangement → version → occurrence →
      # attention projection. Do not lock the occurrence before the Arrangement (milestone
      # replacement locks Arrangement first).
      locked_agency = Agency.lock.find_by(id: agency.id)
      next if locked_agency.nil? || !locked_agency.active?

      departure = locked_agency.departures.lock.find_by(id: occurrence.departure_id)
      next if departure.nil?

      arrangement = locked_agency.supplier_arrangements.lock.find_by(
        id: occurrence.supplier_arrangement_id
      )
      next if arrangement.nil?

      version = arrangement.versions.lock.find_by(
        id: occurrence.supplier_arrangement_version_id
      )
      next if version.nil?

      locked = SupplierDeadlineOccurrence.lock.find_by(
        id: occurrence.id, agency_id: locked_agency.id
      )
      next if locked.nil? || locked.superseded_at.present?

      RefreshSupplierDeadlineProjection.call(occurrence: locked)
      RebuildSupplierAttentionProjectionAlreadyLocked.new(
        agency: locked_agency,
        arrangement:,
        version:
      ).call
    end
  end
end
