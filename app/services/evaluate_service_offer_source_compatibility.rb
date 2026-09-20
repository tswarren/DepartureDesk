# frozen_string_literal: true

class EvaluateServiceOfferSourceCompatibility < AgencyCommand
  include OfferCommandSupport

  Outcome = Data.define(:result, :binding_outcomes, :annotations)
  BindingOutcome = Data.define(:binding_id, :result, :reasons)
  RESULTS = %w[equivalent material unknown].freeze

  def initialize(agency:, actor:, offer:, version: nil)
    @agency = agency
    @actor = actor
    @offer = offer
    @version = version
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_departures)
    offer = @agency.service_offers.find(@offer.id)
    version = @version ? offer.versions.find(@version.id) : offer.editable_draft_version
    raise AgencyCommand::Error.new("That service offer version was not found.", code: :not_found) if version.nil?

    annotations = {
      "cost_graph_not_compared" => true,
      "pool_projections" => []
    }
    outcomes = version.source_bindings.order(:position).map { |binding|
      evaluate_binding(binding, annotations)
    }
    overall = if outcomes.any? { |row| row.result == "unknown" }
      "unknown"
    elsif outcomes.any? { |row| row.result == "material" }
      "material"
    else
      "equivalent"
    end
    Outcome.new(result: overall, binding_outcomes: outcomes, annotations: annotations)
  end

  private

  def evaluate_binding(binding, annotations)
    reasons = []
    bound_version = binding.supplier_arrangement_version
    arrangement = binding.supplier_arrangement
    current = arrangement.governing_version

    if bound_version.draft?
      return BindingOutcome.new(binding_id: binding.id, result: "unknown", reasons: [ "Bound source is not an activated version." ])
    end
    unless bound_version.activated? || bound_version.superseded?
      return BindingOutcome.new(binding_id: binding.id, result: "unknown", reasons: [ "Bound source is not an activated version." ])
    end
    if current.nil? || !current.activated?
      return BindingOutcome.new(binding_id: binding.id, result: "unknown", reasons: [ "There is no current activated successor to compare." ])
    end
    if current.draft?
      return BindingOutcome.new(binding_id: binding.id, result: "unknown", reasons: [ "A successor draft does not enter this comparison." ])
    end

    record_pool_annotation(binding, annotations)

    if current.id == bound_version.id
      return BindingOutcome.new(binding_id: binding.id, result: "equivalent", reasons: [])
    end

    current_item = current.arrangement_item_definitions.find_by(arrangement_item_id: binding.arrangement_item_id)
    lineage = lineage_reaches?(current_item, binding.arrangement_item_definition_id, ArrangementItemDefinition)
    return unknown_missing(binding) if lineage == :unknown
    return material(binding, "The bound Item is omitted or replaced.") if lineage == :missing_current

    compare_item!(reasons, binding, current_item, arrangement, current)
    compare_occurrence!(reasons, binding, current)
    compare_resource!(reasons, binding, current)
    compare_pool!(reasons, binding, current)

    unknown_reason = reasons.find { |reason| reason.is_a?(Symbol) }
    if unknown_reason
      message = case unknown_reason
      when :unknown_occurrence_lineage then "Occurrence lineage is missing."
      when :unknown_resource_lineage then "Resource lineage is missing."
      when :unknown_pool_lineage then "Pool lineage is missing."
      else "Source lineage is missing."
      end
      return BindingOutcome.new(binding_id: binding.id, result: "unknown", reasons: [ message ])
    end

    result = reasons.any? ? "material" : "equivalent"
    BindingOutcome.new(binding_id: binding.id, result: result, reasons: reasons)
  end

  def lineage_reaches?(current_definition, bound_definition_id, model)
    return :missing_current if current_definition.nil?

    seen = {}
    node = current_definition
    while node
      return true if node.id == bound_definition_id
      return :unknown if seen[node.id]
      seen[node.id] = true
      return :unknown if node.copied_from_id.blank?

      node = model.find_by(id: node.copied_from_id)
      return :unknown if node.nil?
    end
    :unknown
  end

  def compare_item!(reasons, binding, successor_item, arrangement, current)
    predecessor = binding.arrangement_item_definition
    predecessor_provider = effective_provider_for(arrangement, predecessor, binding.service_occurrence_definition)
    successor_occurrence = if binding.service_occurrence_id
      current.service_occurrence_definitions.find_by(service_occurrence_id: binding.service_occurrence_id)
    end
    successor_provider = effective_provider_for(arrangement, successor_item, successor_occurrence)
    if predecessor_provider.id != successor_provider.id
      reasons << "Effective provider changed."
    end
    if predecessor.category != successor_item.category ||
        predecessor.other_category_label != successor_item.other_category_label ||
        predecessor.capacity_management != successor_item.capacity_management
      reasons << "Item category or capacity-management changed."
    end
    if binding.depend_on_item_name && predecessor.name != successor_item.name
      reasons << "Dependent Item name changed."
    end
    if binding.depend_on_item_description && predecessor.description != successor_item.description
      reasons << "Dependent Item description changed."
    end
  end

  def compare_occurrence!(reasons, binding, current)
    return if binding.service_occurrence_id.blank?

    occurrence = binding.service_occurrence
    reasons << "The bound Occurrence is cancelled." if occurrence.cancelled?

    successor = current.service_occurrence_definitions.find_by(service_occurrence_id: binding.service_occurrence_id)
    lineage = lineage_reaches?(successor, binding.service_occurrence_definition_id, ServiceOccurrenceDefinition)
    if lineage == :unknown
      reasons << :unknown_occurrence_lineage
      return
    end
    if lineage == :missing_current
      reasons << "The bound Occurrence is omitted or replaced."
      return
    end
    predecessor = binding.service_occurrence_definition
    if predecessor.service_provider_id != successor.service_provider_id ||
        predecessor.starts_on != successor.starts_on ||
        predecessor.ends_on != successor.ends_on ||
        predecessor.starts_at_local != successor.starts_at_local ||
        predecessor.ends_at_local != successor.ends_at_local ||
        predecessor.time_zone != successor.time_zone
      reasons << "Promised Occurrence dates, times, zone, or provider changed."
    end
    if binding.depend_on_occurrence_name && predecessor.name != successor.name
      reasons << "Dependent Occurrence name changed."
    end
    if binding.depend_on_occurrence_description && predecessor.description != successor.description
      reasons << "Dependent Occurrence description changed."
    end
  end

  def compare_resource!(reasons, binding, current)
    return if binding.supplier_resource_id.blank?

    successor = current.supplier_resource_definitions.find_by(supplier_resource_id: binding.supplier_resource_id)
    lineage = lineage_reaches?(successor, binding.supplier_resource_definition_id, SupplierResourceDefinition)
    if lineage == :unknown
      reasons << :unknown_resource_lineage
      return
    end
    if lineage == :missing_current
      reasons << "The bound Resource is omitted or replaced."
      return
    end
    predecessor = binding.supplier_resource_definition
    if binding.depend_on_resource_name && predecessor.name != successor.name
      reasons << "Dependent Resource name changed."
    end
    if binding.depend_on_resource_description && predecessor.description != successor.description
      reasons << "Dependent Resource description changed."
    end
    return if binding.service_occurrence_id.blank?

    predecessor_pair = CapacityPairDefinition.find_by(
      supplier_arrangement_version_id: binding.supplier_arrangement_version_id,
      service_occurrence_id: binding.service_occurrence_id,
      supplier_resource_id: binding.supplier_resource_id
    )
    successor_pair = CapacityPairDefinition.find_by(
      supplier_arrangement_version_id: current.id,
      service_occurrence_id: binding.service_occurrence_id,
      supplier_resource_id: binding.supplier_resource_id
    )
    if predecessor_pair&.classification != successor_pair&.classification
      reasons << "Bound pair classification changed."
    end
  end

  def compare_pool!(reasons, binding, current)
    return if binding.capacity_pool_id.blank?

    successor = current.capacity_pool_definitions.find_by(capacity_pool_id: binding.capacity_pool_id)
    lineage = lineage_reaches?(successor, binding.capacity_pool_definition_id, CapacityPoolDefinition)
    if lineage == :unknown
      reasons << :unknown_pool_lineage
      return
    end
    if lineage == :missing_current
      reasons << "The bound Pool is omitted or replaced."
      return
    end
    predecessor = binding.capacity_pool_definition
    if binding.depend_on_pool_label && predecessor.label != successor.label
      reasons << "Dependent Pool label changed."
    end
    if binding.depend_on_pool_unit_label && predecessor.unit_label != successor.unit_label
      reasons << "Dependent Pool unit label changed."
    end
  end

  def record_pool_annotation(binding, annotations)
    return if binding.capacity_pool_id.blank?

    projection = CapacityProjection.find_by(capacity_pool_id: binding.capacity_pool_id)
    annotations["pool_projections"] << {
      "capacity_pool_id" => binding.capacity_pool_id,
      "current_supplier_capacity" => projection&.current_supplier_capacity,
      "rebuilt_at" => projection&.rebuilt_at&.iso8601
    }
  end

  def unknown_missing(binding)
    BindingOutcome.new(binding_id: binding.id, result: "unknown", reasons: [ "Item lineage is missing." ])
  end

  def material(binding, reason)
    BindingOutcome.new(binding_id: binding.id, result: "material", reasons: [ reason ])
  end
end
