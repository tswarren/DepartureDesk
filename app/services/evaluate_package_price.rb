# frozen_string_literal: true

class EvaluatePackagePrice
  def initialize(package:, version: nil, scenario: {}, selected_inclusion_ids: [], selected_option_ids: [])
    @package = package
    @version = version || package.editable_draft_version
    @scenario = scenario.is_a?(EvaluateClientPrice::Scenario) ? scenario : EvaluateClientPrice::Scenario.build(scenario.merge(selected_option_ids: selected_option_ids))
    @selected_inclusion_ids = Array(selected_inclusion_ids).map(&:to_s)
  end

  def call
    return incomplete("That package has no editable draft.") if @version.nil?

    definition = @version.price_definition
    return incomplete("A Package price is required.", field: :price) if definition.nil?

    cap_blocker = cap_incomplete
    return cap_blocker if cap_blocker

    if definition.bundled?
      evaluate_bundled(definition)
    else
      evaluate_service_sum(definition)
    end
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
