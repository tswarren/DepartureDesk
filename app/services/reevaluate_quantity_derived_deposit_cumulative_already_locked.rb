# frozen_string_literal: true

# Internal helper. Caller must already hold Arrangement / version / pool locks as needed.
# Re-evaluates open quantity-derived cumulative deposit tranches against current retained
# capacity and appends adjustment components (never overwrites historical snapshots).
class ReevaluateQuantityDerivedDepositCumulativeAlreadyLocked
  def initialize(agency:, actor:, arrangement:, version:, at: Time.current)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @at = at
  end

  # @param pool_ids [Array<UUID>, nil] when set, only cumulative defs covering those pools
  def call(pool_ids: nil)
    return [] if @actor.nil?

    adjusted = []
    quantity_derived_tranches.each do |tranche|
      next if pool_ids.present? && !covers_any_pool?(tranche, pool_ids)

      commitment = tranche.supplier_commitment
      next if commitment.nil? || !commitment.open_state?

      refresh_covered_projections!(tranche)
      evaluated = SupplierDepositAmountEvaluator.call(
        definition: tranche.supplier_deposit_requirement_definition,
        version: @version,
        arrangement: @arrangement,
        mode: :materialize,
        at: @at
      )
      target = evaluated.fetch(:amount_minor_units)
      delta = target - tranche.current_amount_minor_units
      next if delta.zero?

      apply_adjustment!(tranche, delta, evaluated)
      adjusted << tranche.reload
    end
    if adjusted.any?
      RebuildSupplierExposureProjectionAlreadyLocked.new(
        agency: @agency,
        arrangement: @arrangement,
        version: @version,
        at: @at
      ).call
    end
    adjusted
  rescue SupplierDepositAmountEvaluator::IncompleteCalculation => error
    raise AgencyCommand::Error.new(error.message, code: :invalid)
  end

  private

  def quantity_derived_tranches
    @version.supplier_deposit_requirement_tranches
      .includes(
        :supplier_commitment,
        supplier_deposit_requirement_definition: [
          :supplier_deposit_requirement_definition_coverage_links,
          :supplier_deposit_requirement_definition_contributor_links
        ]
      )
      .order(:materialized_at, :id)
      .lock
      .select { |tranche| quantity_derived?(tranche.supplier_deposit_requirement_definition) }
  end

  def quantity_derived?(definition)
    definition.amount_shape == "cumulative_target" &&
      definition.quantity_basis == "capacity_pool_units" &&
      definition.rate_minor_units.present?
  end

  def covers_any_pool?(tranche, pool_ids)
    wanted = pool_ids.map(&:to_s)
    links = tranche.supplier_deposit_requirement_definition
      .supplier_deposit_requirement_definition_coverage_links
    links.any? { |link| wanted.include?(link.capacity_pool_id.to_s) }
  end

  def refresh_covered_projections!(tranche)
    links = tranche.supplier_deposit_requirement_definition
      .supplier_deposit_requirement_definition_coverage_links
    links.each do |link|
      pool_id = link.capacity_pool_id
      next if pool_id.blank?

      pool = CapacityPool.find_by(
        id: pool_id, agency_id: @agency.id, supplier_arrangement_id: @arrangement.id
      )
      next if pool.nil?

      projection = pool.capacity_projection
      next if projection.nil?

      projection.lock!
      CapacityProjectionRefresher.call(pool:, projection:, now: @at)
    end
  end

  def apply_adjustment!(tranche, delta, evaluated)
    now = @at
    new_amount = tranche.current_amount_minor_units + delta
    raise AgencyCommand::Error.new("Deposit amount cannot be negative.", code: :invalid) if new_amount.negative?

    kind = delta.positive? ? "adjustment_increase" : "adjustment_decrease"
    SupplierDepositRequirementTrancheComponent.create!(
      agency_id: tranche.agency_id,
      departure_id: tranche.departure_id,
      supplier_arrangement_id: tranche.supplier_arrangement_id,
      supplier_arrangement_version_id: tranche.supplier_arrangement_version_id,
      supplier_deposit_requirement_tranche: tranche,
      component_kind: kind,
      amount_delta_minor_units: delta,
      calculation_snapshot: {
        "reason" => "quantity_derived_cumulative_reevaluation",
        "prior_amount_minor_units" => tranche.current_amount_minor_units,
        "new_amount_minor_units" => new_amount,
        "inputs" => evaluated[:inputs],
        "components" => evaluated[:components]
      },
      note: "Retained capacity reevaluation",
      actor: @actor,
      recorded_at: now
    )
    tranche.apply_current_amount!(amount_minor_units: new_amount)
  end
end
