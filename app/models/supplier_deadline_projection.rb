# frozen_string_literal: true

class SupplierDeadlineProjection < ApplicationRecord
  STATUSES = %w[upcoming warning due overdue].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deadline_occurrence

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deadline_occurrence_id

  validates :status, :overdue_at, :refreshed_at, presence: true
end
