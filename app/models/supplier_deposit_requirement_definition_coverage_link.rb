# frozen_string_literal: true

class SupplierDepositRequirementDefinitionCoverageLink < ApplicationRecord
  include DraftVersionDefinition

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_deposit_requirement_definition
  belongs_to :arrangement_item, optional: true
  belongs_to :service_occurrence, optional: true
  belongs_to :supplier_resource, optional: true
  belongs_to :capacity_pool, optional: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_deposit_requirement_definition_id

  validates :position, numericality: { only_integer: true, greater_than: 0 }
  validate :exactly_one_target_kind

  def target_kind
    return "capacity_pool" if capacity_pool_id.present?
    return "supplier_resource" if supplier_resource_id.present?
    return "service_occurrence" if service_occurrence_id.present?
    return "arrangement_item" if arrangement_item_id.present?

    nil
  end

  private

  def exactly_one_target_kind
    valid =
      (arrangement_item_id.present? && service_occurrence_id.blank? &&
        supplier_resource_id.blank? && capacity_pool_id.blank?) ||
      (arrangement_item_id.present? && service_occurrence_id.present? &&
        supplier_resource_id.blank? && capacity_pool_id.blank?) ||
      (arrangement_item_id.present? && supplier_resource_id.present? &&
        service_occurrence_id.blank? && capacity_pool_id.blank?) ||
      (arrangement_item_id.present? && service_occurrence_id.present? &&
        supplier_resource_id.present? && capacity_pool_id.present?)
    errors.add(:base, "Coverage link must target exactly one source kind") unless valid
  end
end
