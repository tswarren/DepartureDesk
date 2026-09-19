# frozen_string_literal: true

class SupplierDepositRequirementTrancheComponent < ApplicationRecord
  include AppendOnlyRecord

  COMPONENT_KINDS = %w[
    initial_calculation adjustment_increase adjustment_decrease post_satisfaction_increment
  ].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_requirement_tranche
  belongs_to :actor, class_name: "AgencyUser"

  enum :component_kind, COMPONENT_KINDS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id

  validates :amount_delta_minor_units, numericality: { only_integer: true }
  validates :recorded_at, presence: true
  validates :note, length: { maximum: 2000 }, allow_nil: true
end
