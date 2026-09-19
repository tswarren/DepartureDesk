# frozen_string_literal: true

# Internal activation helper. Caller must already hold the exact-version lock graph.
class MaterializeSupplierDepositRequirementDefinitionsAlreadyLocked
  def initialize(agency:, actor:, arrangement:, version:, activation:, departure:,
    predecessor_version: nil, at: Time.current)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @activation = activation
    @departure = departure
    @predecessor_version = predecessor_version
    @at = at
  end

  def call
    reconciler = build_reconciler
    reconciler&.assert_removals_resolved!

    tranches = []
    commitments = []
    occurrences = []
    definitions = @version.supplier_deposit_requirement_definitions
      .includes(
        :supplier_deposit_requirement_definition_coverage_links,
        :supplier_deposit_requirement_definition_cost_links
      )
      .order(:position, :id)
      .lock

    definitions.each do |definition|
      next if reconciler&.skip_open?(definition)

      result = materialize_definition!(definition)
      tranches << result[:tranche]
      commitments << result[:commitment]
      occurrences << result[:occurrence] if result[:occurrence]
      reconciler&.after_open!(result[:commitment], definition)
    end

    { tranches:, commitments:, occurrences: }
  end

  def preview_elapsed
    @version.supplier_deposit_requirement_definitions.order(:position, :id).filter_map do |definition|
      evaluated = SupplierDeadlineRuleEvaluator.call(
        definition:,
        departure: @departure,
        at: @at,
        allow_milestones: true,
        unresolved_milestone_policy: :use_other_arm
      )
      provisional = SupplierDeadlineOccurrence.new(
        precision: definition.precision,
        time_zone: definition.time_zone,
        calculated_on: evaluated[:calculated_on],
        calculated_at: evaluated[:calculated_at],
        supplier_deposit_requirement_definition: definition
      )
      next unless provisional.elapsed?(at: @at)

      {
        definition:,
        calculated_on: evaluated[:calculated_on],
        calculated_at: evaluated[:calculated_at]
      }
    end
  end

  private

  def build_reconciler
    return unless @predecessor_version

    ReconcileSupplierDepositSuccessorAlreadyLocked.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version, predecessor_version: @predecessor_version, at: @at
    )
  end

  def materialize_definition!(definition)
    key = "definition:#{definition.id}:one_shared"
    existing = SupplierDepositRequirementTranche.find_by(
      supplier_arrangement_version_id: @version.id,
      materialization_key: key
    )
    if existing
      commitment = SupplierCommitment.find_by!(
        supplier_deposit_requirement_tranche_id: existing.id
      )
      return { tranche: existing, commitment:, occurrence: existing.governing_deadline_occurrence }
    end

    evaluated_amount = SupplierDepositAmountEvaluator.call(
      definition:, version: @version, arrangement: @arrangement
    )
    coverage_snapshot = definition.supplier_deposit_requirement_definition_coverage_links
      .order(:position, :id).map do |link|
      {
        "arrangement_item_id" => link.arrangement_item_id,
        "service_occurrence_id" => link.service_occurrence_id,
        "supplier_resource_id" => link.supplier_resource_id,
        "capacity_pool_id" => link.capacity_pool_id,
        "target_kind" => link.target_kind
      }
    end

    occurrence = materialize_due_deadline!(definition, coverage_snapshot)
    predecessor = find_predecessor_tranche(definition)
    tranche = SupplierDepositRequirementTranche.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_deposit_requirement_definition: definition,
      supplier_arrangement_activation: @activation,
      amount_shape: definition.amount_shape,
      amount_inputs_snapshot: evaluated_amount[:inputs],
      coverage_snapshot:,
      initial_amount_minor_units: evaluated_amount[:amount_minor_units],
      current_amount_minor_units: evaluated_amount[:amount_minor_units],
      currency: definition.currency,
      materialization_key: key,
      predecessor_tranche: predecessor,
      governing_deadline_occurrence: occurrence,
      actor: @actor,
      materialized_at: @at
    )
    SupplierDepositRequirementTrancheComponent.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_deposit_requirement_tranche: tranche,
      component_kind: "initial_calculation",
      amount_delta_minor_units: evaluated_amount[:amount_minor_units],
      calculation_snapshot: {
        "components" => evaluated_amount[:components],
        "inputs" => evaluated_amount[:inputs]
      },
      actor: @actor,
      recorded_at: @at
    )
    commitment = OpenSupplierDepositCommitmentAlreadyLocked.new(
      tranche:, actor: @actor, activation: @activation,
      contracting_supplier_id: @arrangement.contracting_supplier_id
    ).call
    { tranche:, commitment:, occurrence: }
  rescue ActiveRecord::RecordNotUnique
    tranche = SupplierDepositRequirementTranche.find_by!(
      supplier_arrangement_version_id: @version.id,
      materialization_key: key
    )
    {
      tranche:,
      commitment: SupplierCommitment.find_by!(supplier_deposit_requirement_tranche_id: tranche.id),
      occurrence: tranche.governing_deadline_occurrence
    }
  rescue SupplierDepositAmountEvaluator::IncompleteCalculation => error
    raise AgencyCommand::Error.new(error.message, code: :invalid)
  end

  def materialize_due_deadline!(definition, coverage_snapshot)
    key = "deposit_definition:#{definition.id}:due"
    existing = SupplierDeadlineOccurrence.find_by(
      supplier_arrangement_version_id: @version.id,
      materialization_key: key
    )
    return existing if existing

    evaluated = SupplierDeadlineRuleEvaluator.call(
      definition:,
      departure: @departure,
      at: @at,
      allow_milestones: true,
      unresolved_milestone_policy: :use_other_arm,
      milestone_occurrences: @arrangement.supplier_planning_milestone_occurrences
        .where(supplier_arrangement_version_id: [ @version.id, @predecessor_version&.id ].compact)
    )
    occurrence = SupplierDeadlineOccurrence.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_deadline_definition: nil,
      supplier_deposit_requirement_definition: definition,
      supplier_arrangement_activation: @activation,
      deadline_type: "deposit_due",
      kind: "actionable",
      rule_shape: definition.rule_shape,
      rule_parameters_snapshot: definition.rule_parameters,
      rule_inputs_snapshot: evaluated[:rule_inputs_snapshot],
      precision: definition.precision,
      time_zone: definition.time_zone,
      cardinality: "one_shared",
      coverage_snapshot:,
      calculated_on: evaluated[:calculated_on],
      calculated_at: evaluated[:calculated_at],
      materialization_key: key,
      actor: @actor,
      materialized_at: @at
    )
    RefreshSupplierDeadlineProjection.call(occurrence:, at: @at)
    occurrence
  end

  def find_predecessor_tranche(definition)
    return unless definition.copied_from_id

    SupplierDepositRequirementTranche
      .where(
        agency_id: @agency.id,
        supplier_arrangement_id: @arrangement.id,
        supplier_deposit_requirement_definition_id: definition.copied_from_id
      )
      .order(:materialized_at, :id)
      .lock
      .last
  end
end
