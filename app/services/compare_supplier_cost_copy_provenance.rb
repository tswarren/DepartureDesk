# frozen_string_literal: true

class CompareSupplierCostCopyProvenance
  SUPPORTED_ROLES = %w[supplier_charge supplier_credit].freeze
  SUPPORTED_KINDS = %w[fixed unit_rate].freeze

  def self.call(component:, pinned_version_id:, resource_id:)
    new(component:, pinned_version_id:, resource_id:).call
  end

  def initialize(component:, pinned_version_id:, resource_id:)
    @component = component
    @pinned_version_id = pinned_version_id
    @resource_id = resource_id
  end

  def call
    return "independent" if provenance_blank?
    return "missing" unless source_reachable?

    snapshot = @component.copied_from_supplier_cost_component_mapping
    return "unknown" unless SupplierCostComponentCopyFingerprint.valid_snapshot?(snapshot)
    return "unknown" unless comparable?(source)

    digest = SupplierCostComponentCopyFingerprint.hexdigest(source, snapshot)
    digest == @component.copied_from_supplier_cost_component_fingerprint ? "unchanged" : "changed"
  end

  private

  def provenance_blank?
    @component.copied_from_supplier_cost_component_id.nil?
  end

  def source
    @source ||= SupplierCostComponent.find_by(id: @component.copied_from_supplier_cost_component_id)
  end

  def source_reachable?
    return false if source.nil?
    return false if source.agency_id != @component.agency_id || source.departure_id != @component.departure_id
    return false if source.supplier_arrangement_version_id != @pinned_version_id

    source.supplier_cost_definition.supplier_cost_source.supplier_resource_id == @resource_id
  end

  def comparable?(component)
    SUPPORTED_ROLES.include?(component.economic_role) && SUPPORTED_KINDS.include?(component.calculation_kind)
  end
end
