# frozen_string_literal: true

class SupplierOperatingThresholdOutcome < ApplicationRecord
  OUTCOMES = %w[operate cancel].freeze
  EVIDENCE_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :arrangement_item
  belongs_to :service_occurrence
  belongs_to :supplier_operating_threshold_definition
  belongs_to :recorded_by, class_name: "AgencyUser"

  enum :outcome, OUTCOMES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_operating_threshold_definition_id, :observed_quantity,
    :outcome, :evidence, :occurred_on, :recorded_by_id, :recorded_at

  normalizes :evidence, with: ->(value) { value.to_s.strip }

  validates :evidence, presence: true, length: { maximum: EVIDENCE_LIMIT }
  validates :occurred_on, :recorded_at, presence: true
  validates :observed_quantity, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
