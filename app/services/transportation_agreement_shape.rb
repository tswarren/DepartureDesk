# frozen_string_literal: true

# Exact supported Transportation shape. Extra or different structure is Advanced
# Supplier planning. A singular incomplete segment stays fillable by the typed save.
class TransportationAgreementShape
  ADVANCED = "Advanced Supplier planning"

  def self.foreign_item?(version)
    version.arrangement_item_definitions.where.not(category: "ground_transportation").exists?
  end

  def self.structural_reason(version, item)
    return ADVANCED if version.service_occurrence_definitions.where(arrangement_item: item).count > 1
    return ADVANCED if version.supplier_resource_definitions.where(arrangement_item: item).count > 1

    pools = version.capacity_pool_definitions.where(arrangement_item: item).includes(:capacity_pool).to_a
    return ADVANCED if pools.size > 1
    pool = pools.first
    if pool && (pool.capacity_pool.measurement_basis != "resource_units" || pool.capacity_pool.inventory_mode != "block")
      return ADVANCED
    end

    sources = version.supplier_cost_sources.where(arrangement_item_id: item.id).to_a
    return ADVANCED if sources.size > 1
    return ADVANCED unless supported_source?(version, item, sources.first, pool)
    return ADVANCED if foreign_usage?(version, item)

    nil
  end

  def self.review_reason(version, item)
    structural = structural_reason(version, item)
    return structural if structural

    occurrence = version.service_occurrence_definitions.find_by(arrangement_item: item)
    resource = version.supplier_resource_definitions.find_by(arrangement_item: item)
    pool = version.capacity_pool_definitions.find_by(arrangement_item: item)
    return "Add one segment occurrence." if occurrence.nil?
    return "Add one motorcoach." if resource.nil?
    return "Enter a pickup and drop-off." if occurrence.origin_name.blank? || occurrence.destination_name.blank?
    return "Enter passenger capacity per motorcoach." if resource.maximum_occupancy.blank?
    return "Add one motorcoach Pool." if pool.nil?
    return "Enter the on-request ceiling." if pool.maximum_total_resource_units.blank?

    component = sole_component(version, item)
    return nil if component.nil?
    unless component.unit_rate? && component.resource_units? && component.supplier_charge? && component.supplier_cost_definition.contracted?
      return "The per-coach rate must be a contracted resource-unit charge."
    end
    return "Link the per-coach rate to the motorcoach Pool." if component.quantity_capacity_pool_id.blank?

    nil
  end

  def self.sole_component(version, item)
    source = version.supplier_cost_sources.where(arrangement_item_id: item.id).sole
    definition = source.supplier_cost_definitions.sole
    definition.supplier_cost_components.sole
  rescue ActiveRecord::RecordNotFound, ActiveRecord::SoleRecordExceeded
    nil
  end

  def self.supported_source?(version, item, source, pool)
    return true if source.nil?

    occurrence = version.service_occurrence_definitions.find_by(arrangement_item: item)
    resource = version.supplier_resource_definitions.find_by(arrangement_item: item)
    if occurrence && source.service_occurrence_id != occurrence.service_occurrence_id
      return false
    end
    if resource && source.supplier_resource_id != resource.supplier_resource_id
      return false
    end

    definitions = source.supplier_cost_definitions.to_a
    return false unless definitions.one?

    definition = definitions.first
    return false unless definition.contracted? && definition.calculated?

    components = definition.supplier_cost_components.to_a
    return false unless components.one?

    component = components.first
    return false unless component.supplier_charge? && component.unit_rate? && component.resource_units?
    if component.quantity_capacity_pool_id.present? && pool && component.quantity_capacity_pool_id != pool.capacity_pool_id
      return false
    end

    true
  end

  def self.foreign_usage?(version, item)
    assumption = version.supplier_cost_usage_assumptions.find_by(arrangement_item: item)
    return false if assumption.nil?

    assumption.supplier_cost_occupancy_profiles.exists? ||
      assumption.expected_persons.present? ||
      assumption.expected_billable_nights.present?
  end
  private_class_method :supported_source?, :foreign_usage?
end
