# frozen_string_literal: true

class SupplierDepositRequirementDefinitionCostLink < ApplicationRecord
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_requirement_definition
  belongs_to :supplier_cost_source
  belongs_to :supplier_cost_definition, optional: true
  belongs_to :supplier_cost_component, optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deposit_requirement_definition_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
end
