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
      locked = SupplierDeadlineOccurrence.lock.find_by(
        id: occurrence.id, agency_id: agency.id
      )
      next if locked.nil? || locked.superseded_at.present?

      RefreshSupplierDeadlineProjection.call(occurrence: locked)
    end
  end
end
