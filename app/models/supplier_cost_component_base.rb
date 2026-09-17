class SupplierCostComponentBase < ApplicationRecord
  include ExactVersionCopyLineage
  DIRECTIONS = %w[add subtract].freeze

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_cost_definition
  belongs_to :supplier_cost_component
  belongs_to :base_component, class_name: "SupplierCostComponent"

  enum :direction, DIRECTIONS.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_cost_definition_id,
    :supplier_cost_component_id, :base_component_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
