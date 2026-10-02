# frozen_string_literal: true

module TransportationConfirmationFreeze
  MESSAGE = "Transportation agreement definitions are immutable after Supplier confirmation"

  module Model
    extend ActiveSupport::Concern

    included do
      validate :transportation_definition_remains_editable
      before_destroy :transportation_definition_remains_destroyable
    end

    private

    def transportation_definition_remains_editable
      return unless TransportationConfirmationFreeze.frozen?(self)

      errors.add(:base, TransportationConfirmationFreeze::MESSAGE)
    end

    def transportation_definition_remains_destroyable
      return unless TransportationConfirmationFreeze.frozen?(self)

      errors.add(:base, TransportationConfirmationFreeze::MESSAGE)
      throw :abort
    end
  end

  def self.frozen?(record)
    version_id = record.try(:supplier_arrangement_version_id)
    return false if version_id.blank?
    return false unless SupplierConfirmation.exists?(supplier_arrangement_version_id: version_id)

    affects_transportation?(record)
  end

  def self.affects_transportation?(record)
    version_id = record.supplier_arrangement_version_id
    transportation_ids = CapacityPoolDefinition.where(supplier_arrangement_version_id: version_id)
      .where.not(maximum_total_resource_units: nil).pluck(:arrangement_item_id)
    return false if transportation_ids.empty? && !record.is_a?(ArrangementItemDefinition)

    case record
    when ArrangementItemDefinition
      transportation_ids.include?(record.arrangement_item_id) &&
        (record.category == "ground_transportation" || record.category_was == "ground_transportation")
    when ServiceOccurrenceDefinition, SupplierResourceDefinition, CapacityPairDefinition, CapacityPoolDefinition
      transportation_ids.include?(record.arrangement_item_id)
    when SupplierCostSource
      transportation_ids.include?(record.arrangement_item_id)
    when SupplierCostDefinition
      transportation_ids.include?(record.supplier_cost_source.arrangement_item_id)
    when SupplierCostComponent
      transportation_ids.include?(record.supplier_cost_definition.supplier_cost_source.arrangement_item_id)
    when SupplierDeadlineDefinition
      coverage_affects?(record.supplier_deadline_definition_coverage_links, transportation_ids)
    when SupplierDeadlineDefinitionCoverageLink
      coverage_affects?([ record ], transportation_ids)
    when SupplierAmountDueDefinition, SupplierAmountDueContributor
      transportation_ids.any?
    else
      false
    end
  end

  def self.coverage_affects?(links, transportation_ids)
    links.any? { |link| transportation_ids.include?(link.arrangement_item_id) }
  end
end
