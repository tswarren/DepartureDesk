class SupplierCostUsageAssumption < ApplicationRecord
  include ExactVersionCopyLineage
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :arrangement_item
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true

  has_many :supplier_cost_occupancy_profiles, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :arrangement_item_id,
    :service_occurrence_id, :supplier_resource_id

  validates :expected_resource_units, :expected_persons, :expected_billable_nights,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
end
