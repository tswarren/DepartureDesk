class SupplierCostOccupancyProfile < ApplicationRecord
  include ExactVersionCopyLineage
  LABEL_LIMIT = 120

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :supplier_cost_usage_assumption

  has_many :supplier_cost_occupancy_profile_positions, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :supplier_cost_usage_assumption_id

  normalizes :label, with: ->(value) { value.to_s.strip }

  validates :label, presence: true, length: { maximum: LABEL_LIMIT }
  validates :resource_unit_count, numericality: { only_integer: true, greater_than: 0 }
  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
