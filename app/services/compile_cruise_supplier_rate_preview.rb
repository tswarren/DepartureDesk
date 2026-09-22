# frozen_string_literal: true

class CompileCruiseSupplierRatePreview
  include CruiseSupplierRateSupport

  OccupancyIllustration = Data.define(
    :key, :label, :supported, :gross_minor_units, :commission_minor_units,
    :net_minor_units, :commission_state, :net_state, :complete
  )
  Result = Data.define(
    :compatible?, :empty?, :advanced?, :definition, :source, :currency,
    :stage, :status, :commission_method, :pending_fields, :illustrations,
    :forecast_mix_total_minor_units, :reasons
  )

  def initialize(agency:, arrangement:, resource:, version: nil)
    @agency = agency
    @arrangement = arrangement
    @resource = resource
    @version = version
  end

  def call
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource, version: @version
    ).call

    unless shape.compatible?
      return Result.new(
        compatible?: false, empty?: shape.empty?, advanced?: true,
        definition: shape.definition, source: shape.source,
        currency: nil, stage: nil, status: nil, commission_method: nil,
        pending_fields: [], illustrations: [], forecast_mix_total_minor_units: nil,
        reasons: shape.reasons
      )
    end

    if shape.empty?
      return Result.new(
        compatible?: true, empty?: true, advanced?: false,
        definition: nil, source: nil,
        currency: @arrangement.departure.operating_currency,
        stage: nil, status: nil, commission_method: "not_provided",
        pending_fields: CruiseSupplierRateSupport::CANONICAL_TERM_KEYS.map(&:to_s) + [ "commission" ],
        illustrations: empty_illustrations(shape.resource_definition),
        forecast_mix_total_minor_units: nil,
        reasons: []
      )
    end

    definition = shape.definition
    resource_definition = shape.resource_definition
    commission_method = shape.summary.fetch(:commission_mode)
    pending = pending_fields(definition)
    commission_state, net_state = commission_display_states(definition, commission_method)

    illustrations = build_illustrations(
      definition: definition,
      resource_definition: resource_definition,
      commission_state: commission_state,
      net_state: net_state
    )

    mix_total = combined_forecast_total(definition, shape)

    Result.new(
      compatible?: true, empty?: false, advanced?: false,
      definition: definition, source: shape.source,
      currency: definition.currency, stage: definition.stage, status: definition.status,
      commission_method: commission_method, pending_fields: pending,
      illustrations: illustrations,
      forecast_mix_total_minor_units: mix_total,
      reasons: []
    )
  end

  private

  def pending_fields(definition)
    present = definition.supplier_cost_components.map(&:label).to_set
    fields = []
    CruiseSupplierRateSupport::CANONICAL_SPECS.each do |key, spec|
      fields << key.to_s unless present.include?(spec.fetch(:label))
    end
    fields << "commission" unless present.include?(CruiseSupplierRateSupport::COMMISSION_LABEL)
    fields
  end

  def commission_display_states(definition, commission_method)
    has_commission = definition.supplier_cost_components.any? { |c| c.label == COMMISSION_LABEL }
    if definition.forecast_ready? && !has_commission
      [ "none", "shown" ]
    elsif !has_commission || commission_method == "not_provided"
      [ "pending", "pending" ]
    else
      [ "shown", "shown" ]
    end
  end

  def empty_illustrations(resource_definition)
    CruiseSupplierRateSupport.occupancy_keys_for_maximum(resource_definition&.maximum_occupancy).map do |key|
      OccupancyIllustration.new(
        key: key.to_s,
        label: OCCUPANCY_PROFILE_SPECS.fetch(key).fetch(:label),
        supported: true,
        gross_minor_units: nil,
        commission_minor_units: nil,
        net_minor_units: nil,
        commission_state: "pending",
        net_state: "pending",
        complete: false
      )
    end
  end

  def build_illustrations(definition:, resource_definition:, commission_state:, net_state:)
    keys = CruiseSupplierRateSupport.occupancy_keys_for_maximum(resource_definition.maximum_occupancy)
    category_id = traveler_category_id(definition)
    evaluator = EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: definition.departure,
      arrangement: definition.supplier_arrangement,
      probe_definition: definition,
      version: definition.supplier_arrangement_version
    )

    keys.map do |key|
      spec = OCCUPANCY_PROFILE_SPECS.fetch(key)
      position_count = spec.fetch(:positions)
      profile_id = "ephemeral-#{key}"
      usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
        id: "ephemeral-usage-#{definition.id}",
        expected_persons: position_count,
        expected_resource_units: 1,
        expected_billable_nights: nil
      )
      positions = Array.new(position_count) do |index|
        EvaluateSupplierCostForecast::EphemeralPosition.new(
          id: "#{profile_id}-#{index + 1}",
          occupancy_position: index + 1,
          participant_category_id: category_id
        )
      end
      profiles = [
        EvaluateSupplierCostForecast::PreviewProfile.new(id: profile_id, resource_unit_count: 1)
      ]
      results = evaluator.call_attributed_sources(
        sources: [ definition.supplier_cost_source ],
        usage: usage,
        profiles: profiles,
        positions_by_profile: { profile_id => positions }
      )
      source_result = results.first
      totals = source_result&.totals
      complete = source_result&.complete == true
      OccupancyIllustration.new(
        key: key.to_s,
        label: spec.fetch(:label),
        supported: true,
        gross_minor_units: totals&.forecast_supplier_cost_minor_units,
        commission_minor_units: commission_state == "pending" || commission_state == "none" ?
          nil : totals&.expected_commission_minor_units,
        net_minor_units: net_state == "pending" ? nil : (
          commission_state == "none" ? totals&.forecast_supplier_cost_minor_units :
            totals&.expected_net_cost_after_commission_minor_units
        ),
        commission_state: commission_state,
        net_state: net_state,
        complete: complete
      )
    end
  end

  def traveler_category_id(definition)
    definition.supplier_arrangement_version.supplier_cost_participant_categories
      .find_by(arrangement_item_id: definition.supplier_cost_source.arrangement_item_id, label: PARTICIPANT_CATEGORY_LABEL)
      &.id
  end

  def combined_forecast_total(definition, shape)
    assumption = definition.supplier_arrangement_version.supplier_cost_usage_assumptions.find_by(
      arrangement_item_id: shape.item.id,
      service_occurrence_id: shape.occurrence.id,
      supplier_resource_id: shape.resource.id
    )
    return nil if assumption.nil? || assumption.supplier_cost_occupancy_profiles.empty?

    preview = EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: definition.departure,
      arrangement: definition.supplier_arrangement,
      probe_definition: definition,
      version: definition.supplier_arrangement_version
    ).occupancy_preview(source: definition.supplier_cost_source, assumption: assumption)
    preview&.combined_totals&.forecast_supplier_cost_minor_units
  rescue EvaluateSupplierCostForecast::MissingInput, ArgumentError
    nil
  end
end
