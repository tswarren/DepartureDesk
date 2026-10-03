# frozen_string_literal: true

module ActivityConfirmationFreeze
  MESSAGE = "Activity agreement definitions are immutable after Supplier confirmation"

  module Model
    extend ActiveSupport::Concern

    included do
      validate :activity_definition_remains_editable
      before_destroy :activity_definition_remains_destroyable
    end

    private

    def activity_definition_remains_editable
      return unless ActivityConfirmationFreeze.frozen?(self)

      errors.add(:base, ActivityConfirmationFreeze::MESSAGE)
    end

    def activity_definition_remains_destroyable
      return unless ActivityConfirmationFreeze.frozen?(self)

      errors.add(:base, ActivityConfirmationFreeze::MESSAGE)
      throw :abort
    end
  end

  def self.frozen?(record)
    version_id = record.try(:supplier_arrangement_version_id)
    return false if version_id.blank?
    return false unless SupplierConfirmation.exists?(supplier_arrangement_version_id: version_id)
    return false unless SupplierArrangementVersion.exists?(id: version_id, status: "draft")

    affects_activity?(record)
  end

  def self.affects_activity?(record)
    return true if record.is_a?(SupplierOperatingThresholdDefinition) || record.is_a?(SupplierPaymentRequirementDefinition)

    version_id = record.supplier_arrangement_version_id
    activity_ids = ArrangementItemDefinition.where(
      supplier_arrangement_version_id: version_id, category: "activity_attraction"
    ).pluck(:arrangement_item_id)
    return false if activity_ids.empty? && !record.is_a?(ArrangementItemDefinition)

    case record
    when ArrangementItemDefinition
      record.category == "activity_attraction" || record.category_was == "activity_attraction"
    when ServiceOccurrenceDefinition, SupplierResourceDefinition, CapacityPairDefinition, CapacityPoolDefinition
      activity_ids.include?(record.arrangement_item_id)
    when SupplierCostSource
      activity_ids.include?(record.arrangement_item_id)
    when SupplierCostDefinition
      activity_ids.include?(record.supplier_cost_source.arrangement_item_id)
    when SupplierCostComponent
      activity_ids.include?(record.supplier_cost_definition.supplier_cost_source.arrangement_item_id)
    when SupplierDeadlineDefinition
      record.supplier_deadline_definition_coverage_links.any? { |link| activity_ids.include?(link.arrangement_item_id) }
    when SupplierDeadlineDefinitionCoverageLink
      activity_ids.include?(record.arrangement_item_id)
    else
      false
    end
  end
end
