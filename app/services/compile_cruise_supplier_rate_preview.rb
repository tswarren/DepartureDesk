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

  def initialize(agency:, arrangement:, resource:, version: nil, illustration_occupants: nil)
    @agency = agency
    @arrangement = arrangement
    @resource = resource
    @version = version
    @illustration_occupants = Array(illustration_occupants).map { |label| label.to_s.strip.presence }.compact
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
        pending_fields: %w[matrix commission],
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
      shape: shape,
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
    fields = []
    charge_credit = definition.supplier_cost_components.reject { |c| c.economic_role == "expected_commission" }
    fields << "matrix" if charge_credit.empty?
    fields << "commission" unless definition.supplier_cost_components.any? { |c| c.economic_role == "expected_commission" }
    fields
  end

  def commission_display_states(definition, commission_method)
    has_commission = definition.supplier_cost_components.any? { |c| c.economic_role == "expected_commission" }
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

  def build_illustrations(definition:, resource_definition:, shape:, commission_state:, net_state:)
    categories = participant_categories_for(definition)
    adult = categories.find { |c| c.label.casecmp?(ADULT_CATEGORY_LABEL) }
    child = categories.find { |c| c.label.casecmp?("Child") || c.label.downcase.start_with?("child") }

    scenarios = if @illustration_occupants.any?
      occupant_illustration_scenarios(resource_definition, categories, @illustration_occupants)
    elsif adult && child
      family_illustration_scenarios(resource_definition, adult: adult, child: child)
    else
      standard_illustration_scenarios(resource_definition, categories)
    end

    evaluator = EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: definition.departure,
      arrangement: definition.supplier_arrangement,
      probe_definition: definition,
      version: definition.supplier_arrangement_version
    )

    scenarios.map do |scenario|
      profile_id = "ephemeral-#{scenario.fetch(:key)}"
      usage = EvaluateSupplierCostForecast::EphemeralUsage.new(
        id: "ephemeral-usage-#{definition.id}",
        expected_persons: scenario.fetch(:category_ids).size,
        expected_resource_units: 1,
        expected_billable_nights: nil
      )
      positions = scenario.fetch(:category_ids).each_with_index.map do |category_id, index|
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
        key: scenario.fetch(:key),
        label: scenario.fetch(:label),
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

  def standard_illustration_scenarios(resource_definition, categories)
    default_category_id = categories.find { |c| c.label == PARTICIPANT_CATEGORY_LABEL }&.id ||
      categories.first&.id
    CruiseSupplierRateSupport.occupancy_keys_for_maximum(resource_definition.maximum_occupancy).map do |key|
      spec = OCCUPANCY_PROFILE_SPECS.fetch(key)
      {
        key: key.to_s,
        label: spec.fetch(:label),
        category_ids: Array.new(spec.fetch(:positions)) { default_category_id }
      }
    end
  end

  def family_illustration_scenarios(resource_definition, adult:, child:)
    max = resource_definition.maximum_occupancy.to_i
    scenarios = []
    if max >= 1
      scenarios << { key: "single_adult", label: "Single Adult", category_ids: [ adult.id ] }
    end
    if max >= 2
      scenarios << { key: "double_adult", label: "Double Adult", category_ids: [ adult.id, adult.id ] }
    end
    if max >= 3
      scenarios << {
        key: "two_adults_child",
        label: "Two Adults + Child",
        category_ids: [ adult.id, adult.id, child.id ]
      }
    end
    scenarios
  end

  def occupant_illustration_scenarios(resource_definition, categories, occupants)
    max = [ resource_definition.maximum_occupancy.to_i, occupants.size ].min
    max = 1 if max < 1
    by_label = categories.index_by { |category| category.label.downcase }

    (1..max).filter_map do |count|
      labels = occupants.first(count)
      category_ids = labels.map do |label|
        by_label[label.downcase]&.id
      end
      next if category_ids.any?(&:nil?)

      {
        key: "occupants_#{count}",
        label: labels.join(" + "),
        category_ids: category_ids
      }
    end
  end

  def participant_categories_for(definition)
    definition.supplier_arrangement_version.supplier_cost_participant_categories
      .where(arrangement_item_id: definition.supplier_cost_source.arrangement_item_id)
      .order(:position, :id).to_a
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
