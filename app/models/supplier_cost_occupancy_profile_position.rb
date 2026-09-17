class SupplierCostOccupancyProfilePosition < ApplicationRecord
  include ExactVersionCopyLineage
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :supplier_cost_usage_assumption
  belongs_to :supplier_cost_occupancy_profile
  belongs_to :participant_category, class_name: "SupplierCostParticipantCategory"

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :supplier_cost_usage_assumption_id, :supplier_cost_occupancy_profile_id,
    :participant_category_id, :occupancy_position

  validates :occupancy_position, numericality: { only_integer: true, greater_than: 0 }
end
