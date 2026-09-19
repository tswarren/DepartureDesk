# frozen_string_literal: true

class SupplierExposureSourceQualification < ApplicationRecord
  SOURCE_KINDS = %w[supplier_cost_source].freeze
  QUALIFICATION_BANDS = %w[guaranteed].freeze
  REASON_LIMIT = 120
  NOTE_LIMIT = 2_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :actor, class_name: "AgencyUser"
  belongs_to :agency_command_idempotency_key, optional: true

  enum :source_kind, SOURCE_KINDS.index_by(&:itself), validate: true
  enum :qualification_band, QUALIFICATION_BANDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :source_kind, :source_id

  validates :qualification_reason, presence: true, length: { maximum: REASON_LIMIT }
  validates :note, presence: true, length: { maximum: NOTE_LIMIT }
  validates :source_id, :recorded_at, presence: true
end
