# frozen_string_literal: true

module LodgingConfirmationFreeze
  MESSAGE = "Lodging agreement definitions are immutable after Supplier confirmation"

  module Model
    extend ActiveSupport::Concern

    included do
      validate :lodging_definition_remains_editable
      before_destroy :lodging_definition_remains_destroyable
    end

    private

    def lodging_definition_remains_editable
      return unless LodgingConfirmationFreeze.frozen?(self)

      errors.add(:base, LodgingConfirmationFreeze::MESSAGE)
    end

    def lodging_definition_remains_destroyable
      return unless LodgingConfirmationFreeze.frozen?(self)

      errors.add(:base, LodgingConfirmationFreeze::MESSAGE)
      throw :abort
    end
  end

  def self.frozen?(record)
    version_id = record.try(:supplier_arrangement_version_id)
    return false if version_id.blank?
    return false unless SupplierConfirmation.exists?(supplier_arrangement_version_id: version_id)

    affects_lodging?(record)
  end

  def self.affects_lodging?(record)
    version_id = record.supplier_arrangement_version_id
    lodging_ids = ArrangementItemDefinition.where(
      supplier_arrangement_version_id: version_id, category: "lodging"
    ).pluck(:arrangement_item_id)
    return false if lodging_ids.empty? && record.class.name != "ArrangementItemDefinition"

    case record
    when ArrangementItemDefinition
      record.category == "lodging" || record.category_was == "lodging"
    when ServiceOccurrenceDefinition, SupplierResourceDefinition, CapacityPairDefinition, CapacityPoolDefinition
      lodging_ids.include?(record.arrangement_item_id)
    when SupplierCostSource
      record.arrangement_item_id.nil? || lodging_ids.include?(record.arrangement_item_id)
    when SupplierCostDefinition
      source = record.supplier_cost_source
      source.arrangement_item_id.nil? || lodging_ids.include?(source.arrangement_item_id)
    when SupplierCostComponent
      source = record.supplier_cost_definition.supplier_cost_source
      source.arrangement_item_id.nil? || lodging_ids.include?(source.arrangement_item_id)
    when SupplierDeadlineDefinition
      coverage_affects_lodging?(record.supplier_deadline_definition_coverage_links, lodging_ids)
    when SupplierDepositRequirementDefinition
      coverage_affects_lodging?(record.supplier_deposit_requirement_definition_coverage_links, lodging_ids)
    when SupplierDeadlineDefinitionCoverageLink, SupplierDepositRequirementDefinitionCoverageLink
      coverage_affects_lodging?([ record ], lodging_ids)
    else
      false
    end
  end

  def self.coverage_affects_lodging?(links, lodging_ids)
    links.any? do |link|
      lodging_ids.include?(link.arrangement_item_id) ||
        lodging_occurrence?(link.service_occurrence_id, lodging_ids) ||
        lodging_resource?(link.supplier_resource_id, lodging_ids) ||
        lodging_pool?(link.capacity_pool_id, lodging_ids)
    end
  end

  def self.lodging_occurrence?(id, lodging_ids)
    id.present? && ServiceOccurrence.where(id: id, arrangement_item_id: lodging_ids).exists?
  end

  def self.lodging_resource?(id, lodging_ids)
    id.present? && SupplierResource.where(id: id, arrangement_item_id: lodging_ids).exists?
  end

  def self.lodging_pool?(id, lodging_ids)
    id.present? && CapacityPool.where(id: id, arrangement_item_id: lodging_ids).exists?
  end
end
