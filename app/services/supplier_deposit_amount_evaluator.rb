# frozen_string_literal: true

class SupplierDepositAmountEvaluator
  IncompleteCalculation = Class.new(StandardError)

  def self.call(definition:, version:, arrangement:)
    new(definition:, version:, arrangement:).call
  end

  def initialize(definition:, version:, arrangement:)
    @definition = definition
    @version = version
    @arrangement = arrangement
  end

  def call
    case @definition.amount_shape
    when "fixed_amount"
      amount = @definition.fixed_amount_minor_units
      {
        amount_minor_units: amount,
        components: [ {
          "kind" => "fixed_amount",
          "amount_minor_units" => amount
        } ],
        inputs: { "amount_shape" => "fixed_amount", "fixed_amount_minor_units" => amount }
      }
    when "quantity_times_rate"
      quantity = resolve_quantity
      rate = @definition.rate_minor_units
      amount = quantity * rate
      {
        amount_minor_units: amount,
        components: [ {
          "kind" => "quantity_times_rate",
          "quantity" => quantity,
          "rate_minor_units" => rate,
          "amount_minor_units" => amount
        } ],
        inputs: {
          "amount_shape" => "quantity_times_rate",
          "quantity" => quantity,
          "quantity_basis" => @definition.quantity_basis,
          "rate_minor_units" => rate
        }
      }
    when "percentage_of_cost_sources"
      evaluate_percentage
    when "cumulative_target"
      evaluate_cumulative_target
    else
      raise IncompleteCalculation, "Unsupported deposit amount shape"
    end
  end

  private

  def resolve_quantity
    case @definition.quantity_basis
    when "explicit"
      @definition.explicit_quantity
    when "resource_units"
      quantity_from_resource_units
    when "traveler_positions"
      raise IncompleteCalculation, "Traveler position deposit quantities are not supported yet"
    else
      raise IncompleteCalculation, "Deposit quantity basis is incomplete"
    end
  end

  def quantity_from_resource_units
    links = @definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id)
    raise IncompleteCalculation, "Deposit coverage is required for resource-unit quantities" if links.empty?

    total = 0
    links.each do |link|
      assumption = @version.supplier_cost_usage_assumptions.find_by(
        arrangement_item_id: link.arrangement_item_id,
        service_occurrence_id: link.service_occurrence_id,
        supplier_resource_id: link.supplier_resource_id
      )
      units = assumption&.expected_resource_units
      if units.nil?
        # One covered resource counts as one unit when no usage assumption is entered.
        units = link.supplier_resource_id.present? ? 1 : nil
      end
      raise IncompleteCalculation, "Resource-unit quantity is incomplete" if units.nil?

      total += units
    end
    raise IncompleteCalculation, "Resource-unit quantity must be positive" unless total.positive?

    total
  end

  def evaluate_percentage
    links = @definition.supplier_deposit_requirement_definition_cost_links.order(:position, :id)
    raise IncompleteCalculation, "Select at least one cost source for a percentage deposit" if links.empty?

    percentage = @definition.percentage.to_d
    bases = links.map { |link| cost_base_minor_units(link) }
    amount =
      if @definition.rounding_scope == "per_source"
        bases.sum { |base| ((base * percentage) / 100).round }
      else
        ((bases.sum * percentage) / 100).round
      end
    {
      amount_minor_units: amount,
      components: bases.each_with_index.map do |base, index|
        {
          "kind" => "percentage_base",
          "supplier_cost_source_id" => links[index].supplier_cost_source_id,
          "base_minor_units" => base,
          "percentage" => percentage.to_s("F")
        }
      end,
      inputs: {
        "amount_shape" => "percentage_of_cost_sources",
        "percentage" => percentage.to_s("F"),
        "rounding_scope" => @definition.rounding_scope,
        "bases" => bases
      }
    }
  end

  def cost_base_minor_units(link)
    if link.supplier_cost_component_id.present?
      component = link.supplier_cost_component
      raise IncompleteCalculation, "Cost component is incomplete" if component.nil?
      raise IncompleteCalculation, "Cost component amount is incomplete" if component.amount_minor_units.nil?

      return component.amount_minor_units
    end

    definition = link.supplier_cost_definition ||
      link.supplier_cost_source.supplier_cost_definitions.find_by(status: "forecast_ready") ||
      link.supplier_cost_source.supplier_cost_definitions.order(:position, :id).first
    raise IncompleteCalculation, "Cost definition is incomplete" if definition.nil?

    components = definition.supplier_cost_components.where(economic_role: "supplier_charge")
    amounts = components.filter_map(&:amount_minor_units)
    raise IncompleteCalculation, "Cost source amount is incomplete" if amounts.empty?

    amounts.sum
  end

  def evaluate_cumulative_target
    target = @definition.target_amount_minor_units
    prior = prior_tranche_amounts_sum
    remaining = [ target - prior, 0 ].max
    {
      amount_minor_units: remaining,
      components: [ {
        "kind" => "cumulative_target",
        "target_amount_minor_units" => target,
        "prior_materialized_minor_units" => prior,
        "remaining_minor_units" => remaining
      } ],
      inputs: {
        "amount_shape" => "cumulative_target",
        "target_amount_minor_units" => target,
        "prior_materialized_minor_units" => prior
      }
    }
  end

  def prior_tranche_amounts_sum
    # Sum earlier economic stages toward the same cumulative target once per stage.
    # Prefer this version's tranche; otherwise use the predecessor-lineage tranche.
    # Never subtract this definition's own predecessor cumulative tranche.
    earlier = @version.supplier_deposit_requirement_definitions
      .where("position < ?", @definition.position)
      .order(:position, :id)

    earlier.sum { |peer| governing_prior_amount_for(peer) }
  end

  def governing_prior_amount_for(definition)
    tranche = latest_tranche_for_definition_id(definition.id)
    return tranche.current_amount_minor_units if tranche

    return 0 if definition.copied_from_id.blank?

    latest_tranche_for_definition_id(definition.copied_from_id)&.current_amount_minor_units.to_i
  end

  def latest_tranche_for_definition_id(definition_id)
    SupplierDepositRequirementTranche
      .where(
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_deposit_requirement_definition_id: definition_id
      )
      .order(:materialized_at, :id)
      .last
  end
end
