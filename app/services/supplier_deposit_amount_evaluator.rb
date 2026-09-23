# frozen_string_literal: true

class SupplierDepositAmountEvaluator
  IncompleteCalculation = Class.new(StandardError)

  CoverageSource = Data.define(
    :capacity_pool_id,
    :arrangement_item_id,
    :service_occurrence_id,
    :supplier_resource_id
  )

  def self.call(
    definition:,
    version:,
    arrangement:,
    mode: :materialize,
    at: Time.current,
    coverage_links: nil,
    contributor_definition_ids: nil
  )
    new(
      definition:,
      version:,
      arrangement:,
      mode:,
      at:,
      coverage_links:,
      contributor_definition_ids:
    ).call
  end

  def initialize(
    definition:,
    version:,
    arrangement:,
    mode: :materialize,
    at: Time.current,
    coverage_links: nil,
    contributor_definition_ids: nil
  )
    @definition = definition
    @version = version
    @arrangement = arrangement
    @mode = mode.to_sym
    @at = at
    @coverage_links_override = coverage_links
    @contributor_definition_ids_override = contributor_definition_ids
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

  def coverage_link_rows
    if @coverage_links_override
      Array(@coverage_links_override).map do |raw|
        attrs = raw.to_h.with_indifferent_access
        CoverageSource.new(
          capacity_pool_id: attrs[:capacity_pool_id],
          arrangement_item_id: attrs[:arrangement_item_id],
          service_occurrence_id: attrs[:service_occurrence_id],
          supplier_resource_id: attrs[:supplier_resource_id]
        )
      end
    else
      @definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id).to_a
    end
  end

  def contributor_definitions
    if @contributor_definition_ids_override
      ids = Array(@contributor_definition_ids_override).map(&:to_s)
      raise IncompleteCalculation, "Quantity-derived cumulative targets require contributors" if ids.empty?

      ids.map do |id|
        definition = @version.supplier_deposit_requirement_definitions.find_by(id:)
        raise IncompleteCalculation, "Contributor definition is missing" if definition.nil?

        definition
      end
    else
      links = @definition.supplier_deposit_requirement_definition_contributor_links.order(:position, :id)
      raise IncompleteCalculation, "Quantity-derived cumulative targets require contributors" if links.empty?

      links.map do |link|
        contributor = link.contributor_definition
        raise IncompleteCalculation, "Contributor definition is missing" if contributor.nil?

        contributor
      end
    end
  end

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

  def cumulative_quantity_phase
    return :retained unless @mode == :preview
    return :retained if successor_preview_context?
    return :provisional_retained if @version.draft?

    :retained
  end

  def successor_preview_context?
    @arrangement.versions.where.not(status: "draft").exists?
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
        "quantity_label" => row[:quantity_label],
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
    links = coverage_link_rows
    raise IncompleteCalculation, "Deposit coverage is required for capacity-pool quantities" if links.empty?

    links.map do |link|
      pool = resolve_capacity_pool(link)
      quantity, meta = quantity_for_pool(pool, quantity_phase:)
      {
        capacity_pool_id: pool.id,
        supplier_resource_id: pool.supplier_resource_id,
        quantity:,
        quantity_label: meta[:quantity_label],
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
      scope = CapacityPool.where(
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_resource_id: link.supplier_resource_id,
        arrangement_item_id: link.arrangement_item_id
      )
      if link.service_occurrence_id.present?
        scope = scope.where(service_occurrence_id: link.service_occurrence_id)
      end
      pools = scope.order(:id).to_a
      raise IncompleteCalculation, "Capacity pool for covered resource is missing" if pools.empty?
      if pools.size > 1
        raise IncompleteCalculation,
          "Coverage resource matches multiple capacity pools; name capacity_pool_id explicitly"
      end

      return pools.first
    end

    raise IncompleteCalculation, "Capacity-pool deposits require pool or resource coverage"
  end

  def quantity_for_pool(pool, quantity_phase:)
    case quantity_phase
    when :proposed_opening
      proposed_opening_quantity_for(pool)
    when :provisional_retained
      quantity, meta = proposed_opening_quantity_for(pool)
      [
        quantity,
        meta.merge(quantity_label: "If activated with the current cabin block")
      ]
    when :established_opening
      event = pool.capacity_events.where(event_type: "established")
        .order(:effective_on, :effective_sequence, :id).first
      raise IncompleteCalculation, "Established capacity opening is missing" if event.nil?
      raise IncompleteCalculation, "Established capacity quantity is incomplete" unless event.quantity.positive?

      [ event.quantity, { capacity_event_id: event.id } ]
    when :retained
      projection = ensure_fresh_retained_projection!(pool)
      quantity = projection.current_supplier_capacity
      raise IncompleteCalculation, "Retained capacity quantity is incomplete" if quantity.nil?
      raise IncompleteCalculation, "Retained capacity quantity must be positive" unless quantity.positive?

      [ quantity, { projection_id: projection.id } ]
    else
      raise IncompleteCalculation, "Unsupported capacity quantity phase"
    end
  end

  def proposed_opening_quantity_for(pool)
    definition = @version.capacity_pool_definitions.find_by(capacity_pool_id: pool.id)
    raise IncompleteCalculation, "Capacity pool definition is incomplete" if definition.nil?

    quantity = definition.proposed_opening_quantity
    raise IncompleteCalculation, "Proposed opening quantity is incomplete" if quantity.nil? || quantity <= 0

    [ quantity, {} ]
  end

  def ensure_fresh_retained_projection!(pool)
    projection = pool.capacity_projection
    raise IncompleteCalculation, "Capacity projection is missing for retained quantity" if projection.nil?

    CapacityProjectionRefresher.call(pool:, projection:, now: @at)
    projection.reload
    if projection.next_applies_at.present? && projection.next_applies_at <= @at
      raise IncompleteCalculation, "Capacity projection is stale for retained quantity"
    end

    projection
  end

  def quantity_from_resource_units
    links = coverage_link_rows
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
    contributors = contributor_definitions
    retained_sources = capacity_pool_sources(quantity_phase: cumulative_quantity_phase)
    credits_by_pool = Hash.new(0)
    contributor_traces = []

    contributors.each do |contributor|
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
        "quantity_label" => row[:quantity_label],
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
        "quantity_phase" => cumulative_quantity_phase.to_s,
        "rate_minor_units" => rate,
        "contributors" => contributor_traces,
        "sources" => components
      }
    }
  end

  def credited_amounts_by_pool(contributor)
    tranches = tranches_for_contributor(contributor)
    if tranches.empty?
      return provisional_contributor_credit(contributor) if @mode == :preview

      raise IncompleteCalculation, "Contributor tranche is not materialized"
    end

    by_pool = Hash.new(0)
    tranche_traces = []
    tranches.each do |tranche|
      amounts = pool_amounts_for_contributor_tranche(tranche)
      amounts.each { |pool_id, amount| by_pool[pool_id] += amount }
      tranche_traces << {
        "tranche_id" => tranche.id,
        "current_amount_minor_units" => tranche.current_amount_minor_units,
        "amounts_by_pool" => amounts
      }
    end
    [
      by_pool,
      {
        "contributor_definition_id" => contributor.id,
        "credit_source" => "materialized_tranches",
        "tranches" => tranche_traces,
        "amounts_by_pool" => by_pool
      }
    ]
  end

  def provisional_contributor_credit(contributor)
    evaluated = self.class.call(
      definition: contributor,
      version: @version,
      arrangement: @arrangement,
      mode: :preview,
      at: @at
    )
    by_pool = Hash.new(0)
    Array(evaluated.dig(:inputs, "sources")).each do |row|
      row = row.with_indifferent_access
      pool_id = row[:capacity_pool_id]
      next if pool_id.blank?

      by_pool[pool_id] += row[:amount_minor_units].to_i
    end
    if by_pool.empty? && evaluated[:amount_minor_units].to_i.positive?
      raise IncompleteCalculation,
        "Contributor preview lacks per-source attribution for cumulative credit"
    end

    [
      by_pool,
      {
        "contributor_definition_id" => contributor.id,
        "credit_source" => "draft_contributor_preview",
        "amounts_by_pool" => by_pool,
        "preview_amount_minor_units" => evaluated[:amount_minor_units]
      }
    ]
  end

  def tranches_for_contributor(contributor)
    definition_ids = [ contributor.id, contributor.copied_from_id ].compact
    SupplierDepositRequirementTranche
      .where(
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_deposit_requirement_definition_id: definition_ids
      )
      .order(:materialized_at, :id)
      .to_a
  end

  def pool_amounts_for_contributor_tranche(tranche)
    sources = source_rows_for_tranche(tranche)
    if sources.blank?
      raise IncompleteCalculation, "Contributor lacks per-source calculation trace"
    end

    initial_by_pool = {}
    sources.each do |row|
      row = row.with_indifferent_access
      pool_id = row[:capacity_pool_id]
      raise IncompleteCalculation, "Contributor source pool is incomplete" if pool_id.blank?

      initial_by_pool[pool_id] = row[:amount_minor_units].to_i
    end

    current = tranche.current_amount_minor_units
    return { initial_by_pool.keys.first => current } if initial_by_pool.size == 1

    initial_sum = initial_by_pool.values.sum
    return initial_by_pool if initial_sum == current

    attributed = attributed_adjustment_amounts_by_pool(tranche)
    if attributed.nil?
      raise IncompleteCalculation,
        "Contributor adjustment lacks per-source attribution for multi-pool credit"
    end

    result = initial_by_pool.dup
    attributed.each { |pool_id, delta| result[pool_id] = result.fetch(pool_id, 0) + delta }
    result_sum = result.values.sum
    if result_sum != current
      raise IncompleteCalculation,
        "Contributor source-attributed amounts do not match current tranche amount"
    end
    result
  end

  def source_rows_for_tranche(tranche)
    snapshot = tranche.amount_inputs_snapshot || {}
    rows = Array(snapshot["sources"]).presence || Array(snapshot[:sources])
    return rows if rows.present?

    attributed = snapshot["amounts_by_pool"] || snapshot[:amounts_by_pool]
    if attributed.present?
      return attributed.map do |pool_id, amount|
        { "capacity_pool_id" => pool_id, "amount_minor_units" => amount }
      end
    end

    []
  end

  def attributed_adjustment_amounts_by_pool(tranche)
    deltas = Hash.new(0)
    tranche.supplier_deposit_requirement_tranche_components.order(:recorded_at, :id).each do |component|
      next if component.component_kind == "initial_calculation"

      snapshot = component.calculation_snapshot || {}
      by_pool = snapshot["amounts_by_pool"] || snapshot[:amounts_by_pool]
      return nil if by_pool.blank?

      by_pool.each { |pool_id, amount| deltas[pool_id] += amount.to_i }
    end
    deltas
  end

  def prior_tranche_amounts_sum_by_position
    earlier = @version.supplier_deposit_requirement_definitions
      .where("position < ?", @definition.position)
      .order(:position, :id)

    earlier.sum { |peer| governing_prior_amount_for(peer) }
  end

  def governing_prior_amount_for(definition)
    tranches = SupplierDepositRequirementTranche
      .where(
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_deposit_requirement_definition_id: definition.id
      )
    return tranches.sum(:current_amount_minor_units) if tranches.exists?

    return 0 if definition.copied_from_id.blank?

    SupplierDepositRequirementTranche
      .where(
        agency_id: @arrangement.agency_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_deposit_requirement_definition_id: definition.copied_from_id
      )
      .sum(:current_amount_minor_units)
  end
end
