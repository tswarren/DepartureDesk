# frozen_string_literal: true

class EvaluatePackagePrice
  def initialize(package:, version: nil, scenario: {}, selected_inclusion_ids: [], selected_option_ids: nil)
    @package = package
    @version = version || package.editable_draft_version
    scenario_attrs = scenario.is_a?(EvaluateClientPrice::Scenario) ? nil : scenario.to_h
    if scenario_attrs
      option_ids = selected_option_ids.nil? ? scenario_attrs[:selected_option_ids] || scenario_attrs["selected_option_ids"] : selected_option_ids
      @scenario = EvaluateClientPrice::Scenario.build(scenario_attrs.merge(selected_option_ids: option_ids))
    else
      @scenario = scenario
    end
    @selected_inclusion_ids = Array(selected_inclusion_ids).map(&:to_s)
  end

  def call
    return incomplete("That package has no editable draft.") if @version.nil?

    definition = @version.price_definition
    return incomplete("A Package price is required.", field: :price) if definition.nil?

    cap_blocker = cap_incomplete
    return cap_blocker if cap_blocker

    selection = ValidatePackagePreviewSelections.new(
      package_version: @version,
      scenario: @scenario,
      selected_inclusion_ids: @selected_inclusion_ids
    ).call
    return incomplete(selection.message, field: selection.field) unless selection.ok

    base = if definition.bundled?
      evaluate_bundled(definition)
    else
      evaluate_service_sum(definition)
    end
    return base unless base.complete

    apply_option_effects(base, selection.selected_options)
  end

  private

  def evaluate_bundled(definition)
    graph = EvaluateClientPrice.new(
      definition: graph_hash(definition),
      scenario: EvaluateClientPrice::Scenario.build(persons: 1)
    ).call
    return graph unless graph.complete

    EvaluateClientPrice.new(
      bundled_package: EvaluateClientPrice::BundledPackage.new(
        base_price_minor_units: graph.amount_minor_units,
        currency: graph.currency,
        single_occupancy_supplement_rate: definition.single_occupancy_supplement_rate
      ),
      scenario: @scenario
    ).call
  end

  def evaluate_service_sum(definition)
    results = selected_inclusions.filter_map do |inclusion|
      next if inclusion.optional? && @selected_inclusion_ids.exclude?(inclusion.id.to_s) && @selected_inclusion_ids.any?

      offer_version = inclusion.service_offer_version
      if offer_version.price_definition.nil?
        return incomplete("A selected service is unpriced.", field: :price)
      end

      EvaluateClientPrice.new(definition: offer_version.price_definition, scenario: @scenario).call
    end
    adjustments = definition.package_price_components.sort_by(&:position).map do |component|
      EvaluateClientPrice::NamedAdjustment.new(
        label: component.label,
        amount_minor_units: component.amount_minor_units,
        direction: component.named_discount? ? "subtract" : "add"
      )
    end
    EvaluateClientPrice.new(
      service_sum: EvaluateClientPrice::ServiceSum.new(service_results: results, adjustments: adjustments),
      scenario: @scenario
    ).call
  end

  def apply_option_effects(result, options)
    effect_lines = []
    amount = result.amount_minor_units.to_i
    options.sort_by { |option| [ option.position, option.id ] }.each_with_index do |option, index|
      next if option.price_effect_minor_units.nil?

      signed = option.price_effect_minor_units.to_i
      amount += signed
      effect_lines << EvaluateClientPrice::ComponentLine.new(
        definition_id: nil,
        component_id: option.id,
        label: option.name,
        position: 20_000 + index,
        client_role: "named_surcharge",
        calculation_kind: "fixed",
        quantity: 1,
        rate: nil,
        rounding_mode: "half_up",
        rounding_boundary: "currency_minor_unit",
        percentage_treatment: nil,
        included: false,
        signed_revenue_effect_minor_units: signed,
        formula: { amount_minor_units: signed, evaluated_quantity: 1 }
      )
    end
    return result if effect_lines.empty?

    EvaluateClientPrice::Result.new(
      complete: true,
      amount_minor_units: amount,
      currency: result.currency,
      lines: result.lines + effect_lines,
      blockers: [],
      observed_at: result.observed_at,
      kind: result.kind
    )
  end

  def selected_inclusions
    inclusions = @version.inclusions.includes(service_offer_version: :price_definition).order(:position).to_a
    selected = inclusions.select { |inclusion| inclusion.included? || @selected_inclusion_ids.include?(inclusion.id.to_s) }
    return inclusions.select(&:included?) if @selected_inclusion_ids.empty?

    selected
  end

  def graph_hash(definition)
    {
      id: definition.id,
      currency: definition.currency,
      mode: "calculated",
      components: definition.package_price_components.sort_by(&:position).map do |component|
        {
          id: component.id,
          label: component.label,
          client_role: component.client_role,
          calculation_kind: component.calculation_kind,
          amount_minor_units: component.amount_minor_units,
          rate: component.rate,
          quantity_basis: component.quantity_basis,
          percentage_treatment: component.percentage_treatment,
          position: component.position,
          bases: component.package_price_component_bases.sort_by(&:position).map do |base|
            { base_component_id: base.base_component_id, direction: base.direction, position: base.position }
          end
        }
      end
    }
  end

  def cap_incomplete
    version = @version
    if version.sales_cap_quantity.present?
      quantity = cap_quantity(version.sales_cap_basis)
      if quantity && quantity > version.sales_cap_quantity
        return incomplete("This example exceeds the package sales cap.", field: :sales_cap)
      end
    end
    nil
  end

  def cap_quantity(basis)
    case basis
    when "package_bookings" then 1
    when "persons" then @scenario.persons
    when "resource_units" then @scenario.resource_units
    end
  end

  def incomplete(message, field: :price)
    EvaluateClientPrice::Result.new(
      complete: false,
      amount_minor_units: nil,
      currency: @package.departure.operating_currency,
      lines: [],
      blockers: [ { message: message, field: field, code: :incomplete } ],
      observed_at: Time.current,
      kind: :package
    )
  end
end
