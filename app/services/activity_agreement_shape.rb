# frozen_string_literal: true

# Exact supported Activity shape. Extra or different structure is Advanced
# Supplier planning. A singular incomplete activity stays fillable by the typed save.
class ActivityAgreementShape
  ADVANCED = "Advanced Supplier planning"

  def self.foreign_item?(version)
    version.arrangement_item_definitions.where.not(category: "activity_attraction").exists?
  end

  def self.structural_reason(version, item)
    return ADVANCED if version.service_occurrence_definitions.where(arrangement_item: item).count > 1
    return ADVANCED if version.supplier_resource_definitions.where(arrangement_item: item).count > 1

    pools = version.capacity_pool_definitions.where(arrangement_item: item).includes(:capacity_pool).to_a
    return ADVANCED if pools.size > 1
    pool = pools.first
    if pool && (pool.capacity_pool.measurement_basis != "traveler_positions" || pool.capacity_pool.inventory_mode != "block")
      return ADVANCED
    end

    sources = version.supplier_cost_sources.where(arrangement_item_id: item.id).to_a
    return ADVANCED if sources.size > 1
    return ADVANCED unless supported_source?(version, item, sources.first, pool)
    return ADVANCED if foreign_usage?(version, item)
    return ADVANCED if version.supplier_operating_threshold_definitions.where(arrangement_item: item).count > 1
    return ADVANCED if version.supplier_payment_requirement_definitions.where(arrangement_item: item).count > 1

    nil
  end

  def self.review_reason(version, item)
    structural = structural_reason(version, item)
    return structural if structural

    occurrence = version.service_occurrence_definitions.find_by(arrangement_item: item)
    resource = version.supplier_resource_definitions.find_by(arrangement_item: item)
    pool = version.capacity_pool_definitions.find_by(arrangement_item: item)
    return "Add one activity occurrence." if occurrence.nil?
    return "Add one participant resource." if resource.nil?
    return "Enter the activity location." if occurrence.origin_name.blank?
    return "Add participant spaces." if pool.nil? || pool.proposed_opening_quantity.to_i <= 0
    return "Leave participant occupancy empty." if resource.maximum_occupancy.present?

    component = sole_component(version, item)
    return "Record the Supplier rate per participant." if component.nil?
    unless component.unit_rate? && component.persons? && component.supplier_charge? &&
        component.supplier_cost_definition.contracted? && component.quantity_capacity_pool_id.nil?
      return "The Supplier rate must be a contracted per-person charge."
    end
    return "Record the rate inclusions." unless reference?(version, item, "rate_inclusions")
    return "Record the operating minimum." if version.supplier_operating_threshold_definitions.find_by(arrangement_item: item).nil?
    return "Record the minimum-enrollment review." if deadline(version, item, "other").nil?
    return "Record the final participant count deadline." if deadline(version, item, "final_count_due").nil?
    return "Record the full-payment requirement." if version.supplier_payment_requirement_definitions.find_by(arrangement_item: item).nil?
    return "Record the cancellation wording." unless reference?(version, item, "cancellation")
    return "Record the cancellation cutoff." if deadline(version, item, "cancellation_cutoff").nil?

    nil
  end

  def self.sole_component(version, item)
    source = version.supplier_cost_sources.where(arrangement_item_id: item.id).sole
    definition = source.supplier_cost_definitions.sole
    definition.supplier_cost_components.sole
  rescue ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded
    nil
  end

  def self.deadline(version, item, deadline_type)
    version.supplier_deadline_definitions.joins(:supplier_deadline_definition_coverage_links)
      .where(deadline_type: deadline_type, supplier_deadline_definition_coverage_links: { arrangement_item_id: item.id })
      .order(:position).first
  end

  def self.supported_source?(version, item, source, _pool)
    return true if source.nil?

    occurrence = version.service_occurrence_definitions.find_by(arrangement_item: item)
    resource = version.supplier_resource_definitions.find_by(arrangement_item: item)
    return false if occurrence && source.service_occurrence_id != occurrence.service_occurrence_id
    return false if resource && source.supplier_resource_id != resource.supplier_resource_id

    definitions = source.supplier_cost_definitions.to_a
    return false unless definitions.one?

    definition = definitions.first
    return false unless definition.contracted? && definition.calculated?

    components = definition.supplier_cost_components.to_a
    return false unless components.one?

    component = components.first
    component.supplier_charge? && component.unit_rate? && component.persons? && component.quantity_capacity_pool_id.nil? &&
      !definition.supplier_cost_components.exists?(calculation_kind: "minimum_quantity_shortfall")
  end

  def self.foreign_usage?(version, item)
    assumption = version.supplier_cost_usage_assumptions.find_by(arrangement_item: item)
    return false if assumption.nil?

    assumption.supplier_cost_occupancy_profiles.exists? ||
      assumption.expected_billable_nights.present? ||
      assumption.expected_resource_units.present?
  end

  def self.reference?(version, item, kind)
    version.supplier_agreement_references.exists?(arrangement_item_id: item.id, kind: kind)
  end

  private_class_method :supported_source?, :foreign_usage?, :reference?
end
