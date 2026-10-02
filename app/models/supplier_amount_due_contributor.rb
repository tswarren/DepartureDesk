# frozen_string_literal: true

class SupplierAmountDueContributor < ApplicationRecord
  include ExactVersionCopyLineage
  include DraftVersionDefinition
  include TransportationConfirmationFreeze::Model

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_amount_due_definition
  belongs_to :supplier_cost_component

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_amount_due_definition_id,
    :supplier_cost_component_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
end