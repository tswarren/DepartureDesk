# frozen_string_literal: true

class SupplierDepositAmountEvaluator
  IncompleteCalculation = Class.new(StandardError)

  def self.call(definition:, version:, arrangement:, mode: :materialize)
    new(definition:, version:, arrangement:, mode:).call
  end

  def initialize(definition:, version:, arrangement:, mode: :materialize)
    @definition = definition
    @version = version
    @arrangement = arrangement
    @mode = mode.to_sym
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
      evaluate_quantity_times_rate
    when "percentage_of_cost_sources"
      evaluate_percentage
    when "cumulative_target"
      evaluate_cumulative_target
    else
      raise IncompleteCalculation, "Unsupported deposit amount shape"
    end
  end

  private

  def evaluate_quantity_times_rate
    rate = @definition.rate_minor_units
    case @definition.quantity_basis
    when "explicit"
      quantity = @definition.explicit_quantity
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
    when "resource_units"
      quantity = quantity_from_resource_units
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
    when "capacity_pool_units"
      evaluate_capacity_pool_rate(rate, quantity_phase: opening_phase)
    when "traveler_positions"
      raise IncompleteCalculation, "Traveler position deposit quantities are not supported yet"
    else
      raise IncompleteCalculation, "Deposit quantity basis is incomplete"
    end
  end

  def opening_phase
    @mode == :preview ? :proposed_opening : :established_opening
  end

  def evaluate_capacity_pool_rate(rate, quantity_phase:)
    sources = capacity_pool_sources(quantity_phase:)
    total_quantity = sources.sum { |row| row.fetch(:quantity) }
    raise IncompleteCalculation, "Capacity-pool quantity must be positive" unless total_quantity.positive?

    amount = total_quantity * rate
    components = sources.map do |row|
      {
        "kind" => "capacity_pool_units",
        "capacity_pool_id" => row[:capacity_pool_id],
        "supplier_resource_id" => row[:supplier_resource_id],
        "quantity" => row[:quantity],
        "rate_minor_units" => rate,
        "amount_minor_units" => row[:quantity] * rate,
        "quantity_phase" => quantity_phase.to_s,
        "projection_id" => row[:projection_id],
        "capacity_event_id" => row[:capacity_event_id]
      }
    end
    {
      amount_minor_units: amount,
      components:,
      inputs: {
        "amount_shape" => "quantity_times_rate",
        "quantity" => total_quantity,
        "quantity_basis" => "capacity_pool_units",
        "quantity_phase" => quantity_phase.to_s,
        "rate_minor_units" => rate,
        "sources" => components
      }
    }
  end

  def capacity_pool_sources(quantity_phase:)
    links = @definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id)
    raise IncompleteCalculation, "Deposit coverage is required for capacity-pool quantities" if links.empty?

    links.map do |link|
      pool = resolve_capacity_pool(link)
      quantity, meta = quantity_for_pool(pool, quantity_phase:)
      {
        capacity_pool_id: pool.id,
        supplier_resource_id: pool.supplier_resource_id,
        quantity:,
        projection_id: meta[:projection_id],
        capacity_event_id: meta[:capacity_event_id]
      }
    end
  end

  def resolve_capacity_pool(link)
    if link.capacity_pool_id.present?
      pool = CapacityPool.find_by(
        id: link.capacity_pool_id,
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id
      )
      raise IncompleteCalculation, "Coverage pool is missing" if pool.nil?

      return pool
    end
    if link.supplier_resource_id.present?
      pool = CapacityPool.find_by(
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_resource_id: link.supplier_resource_id,
        arrangement_item_id: link.arrangement_item_id
      )
      raise IncompleteCalculation, "Capacity pool for covered resource is missing" if pool.nil?

      return pool
    end

    raise IncompleteCalculation, "Capacity-pool deposits require pool or resource coverage"
  end

  def quantity_for_pool(pool, quantity_phase:)
    case quantity_phase
    when :proposed_opening
      definition = @version.capacity_pool_definitions.find_by(capacity_pool_id: pool.id)
      raise IncompleteCalculation, "Capacity pool definition is incomplete" if definition.nil?
      quantity = definition.proposed_opening_quantity
      raise IncompleteCalculation, "Proposed opening quantity is incomplete" if quantity.nil? || quantity <= 0

      [ quantity, {} ]
    when :established_opening
      event = pool.capacity_events.where(event_type: "established")
        .order(:effective_on, :effective_sequence, :id).first
      raise IncompleteCalculation, "Established capacity opening is missing" if event.nil?
      raise IncompleteCalculation, "Established capacity quantity is incomplete" unless event.quantity.positive?

      [ event.quantity, { capacity_event_id: event.id } ]
    when :retained
      projection = pool.capacity_projection
      raise IncompleteCalculation, "Capacity projection is missing for retained quantity" if projection.nil?

      quantity = projection.current_supplier_capacity
      raise IncompleteCalculation, "Retained capacity quantity is incomplete" if quantity.nil?
      raise IncompleteCalculation, "Retained capacity quantity must be positive" unless quantity.positive?

      [ quantity, { projection_id: projection.id } ]
    else
      raise IncompleteCalculation, "Unsupported capacity quantity phase"
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
    if quantity_derived_cumulative?
      evaluate_quantity_derived_cumulative
    else
      evaluate_legacy_fixed_cumulative
    end
  end

  def quantity_derived_cumulative?
    @definition.quantity_basis == "capacity_pool_units" && @definition.rate_minor_units.present?
  end

  def evaluate_legacy_fixed_cumulative
    target = @definition.target_amount_minor_units
    prior = prior_tranche_amounts_sum_by_position
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

  def evaluate_quantity_derived_cumulative
    rate = @definition.rate_minor_units
    contributor_links = @definition.supplier_deposit_requirement_definition_contributor_links.order(:position, :id)
    raise IncompleteCalculation, "Quantity-derived cumulative targets require contributors" if contributor_links.empty?

    retained_sources = capacity_pool_sources(quantity_phase: :retained)
    credits_by_pool = Hash.new(0)
    contributor_traces = []

    contributor_links.each do |link|
      contributor = link.contributor_definition
      raise IncompleteCalculation, "Contributor definition is missing" if contributor.nil?

      amount_by_pool, trace = credited_amounts_by_pool(contributor)
      amount_by_pool.each { |pool_id, amount| credits_by_pool[pool_id] += amount }
      contributor_traces << trace
    end

    components = retained_sources.map do |row|
      pool_id = row.fetch(:capacity_pool_id)
      target = row.fetch(:quantity) * rate
      credited = credits_by_pool[pool_id].to_i
      remaining = [ target - credited, 0 ].max
      {
        "kind" => "source_aware_cumulative",
        "capacity_pool_id" => pool_id,
        "supplier_resource_id" => row[:supplier_resource_id],
        "retained_quantity" => row[:quantity],
        "rate_minor_units" => rate,
        "target_minor_units" => target,
        "credited_minor_units" => credited,
        "remaining_minor_units" => remaining,
        "projection_id" => row[:projection_id]
      }
    end
    amount = components.sum { |row| row.fetch("remaining_minor_units") }
    {
      amount_minor_units: amount,
      components:,
      inputs: {
        "amount_shape" => "cumulative_target",
        "quantity_basis" => "capacity_pool_units",
        "rate_minor_units" => rate,
        "contributors" => contributor_traces,
        "sources" => components
      }
    }
  end

  def credited_amounts_by_pool(contributor)
    tranche = latest_tranche_for_definition_id(contributor.id) ||
      (contributor.copied_from_id.present? && latest_tranche_for_definition_id(contributor.copied_from_id))
    raise IncompleteCalculation, "Contributor tranche is not materialized" if tranche.blank?

    sources = Array(tranche.amount_inputs_snapshot["sources"]).presence ||
      Array(tranche.amount_inputs_snapshot[:sources])
    if sources.blank?
      raise IncompleteCalculation, "Contributor lacks per-source calculation trace"
    end

    by_pool = {}
    sources.each do |row|
      row = row.with_indifferent_access
      pool_id = row[:capacity_pool_id]
      raise IncompleteCalculation, "Contributor source pool is incomplete" if pool_id.blank?

      by_pool[pool_id] = row[:amount_minor_units].to_i
    end
    [
      by_pool,
      {
        "contributor_definition_id" => contributor.id,
        "tranche_id" => tranche.id,
        "amounts_by_pool" => by_pool
      }
    ]
  end

  def prior_tranche_amounts_sum_by_position
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
