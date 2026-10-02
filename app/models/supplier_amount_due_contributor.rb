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
  validate :references_belong_to_exact_version

  private

  def references_belong_to_exact_version
    if supplier_amount_due_definition_id.present? &&
        supplier_amount_due_definition&.supplier_arrangement_version_id != supplier_arrangement_version_id
      errors.add(:supplier_amount_due_definition, "must belong to this exact version")
    end
    if supplier_cost_component_id.present? &&
        supplier_cost_component&.supplier_arrangement_version_id != supplier_arrangement_version_id
      errors.add(:supplier_cost_component, "must belong to this exact version")
    end
  end
end