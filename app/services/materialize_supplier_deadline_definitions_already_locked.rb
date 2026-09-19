# frozen_string_literal: true

# Internal activation helper. Caller must already hold the exact-version lock graph.
class MaterializeSupplierDeadlineDefinitionsAlreadyLocked
  def initialize(agency:, actor:, arrangement:, version:, activation:, departure:, at: Time.current)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @activation = activation
    @departure = departure
    @at = at
  end

  def call
    occurrences = []
    commitments = []
    definitions = @version.supplier_deadline_definitions
      .includes(
        :supplier_deadline_definition_coverage_links,
        :supplier_deadline_commitment_definition_lines
      )
      .order(:position, :id)
      .lock

    definitions.each do |definition|
      occurrence = materialize_definition!(definition)
      occurrences << occurrence
      next unless definition.actionable?

      definition.supplier_deadline_commitment_definition_lines.order(:position, :id).each do |line|
        commitments << OpenSupplierDeadlineCommitmentAlreadyLocked.new(
          occurrence:, line:, actor: @actor, activation: @activation
        ).call
      end
    end

    { occurrences:, commitments: }
  end

  def preview_elapsed
    @version.supplier_deadline_definitions.order(:position, :id).filter_map do |definition|
      evaluated = SupplierDeadlineRuleEvaluator.call(
        definition:, departure: @departure, at: @at
      )
      provisional = SupplierDeadlineOccurrence.new(
        precision: definition.precision,
        time_zone: definition.time_zone,
        calculated_on: evaluated[:calculated_on],
        calculated_at: evaluated[:calculated_at],
        supplier_deadline_definition: definition
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

  def materialize_definition!(definition)
    key = "definition:#{definition.id}:one_shared"
    existing = SupplierDeadlineOccurrence.find_by(
      supplier_arrangement_version_id: @version.id,
      materialization_key: key
    )
    return existing if existing

    evaluated = SupplierDeadlineRuleEvaluator.call(
      definition:, departure: @departure, at: @at
    )
    coverage_snapshot = definition.supplier_deadline_definition_coverage_links
      .order(:position, :id).map do |link|
      {
        "arrangement_item_id" => link.arrangement_item_id,
        "service_occurrence_id" => link.service_occurrence_id,
        "supplier_resource_id" => link.supplier_resource_id,
        "capacity_pool_id" => link.capacity_pool_id,
        "target_kind" => link.target_kind
      }
    end

    predecessor = find_predecessor_occurrence(definition)
    occurrence = SupplierDeadlineOccurrence.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_deadline_definition: definition,
      supplier_arrangement_activation: @activation,
      deadline_type: definition.deadline_type,
      other_label: definition.other_label,
      kind: definition.kind,
      rule_shape: definition.rule_shape,
      rule_parameters_snapshot: definition.rule_parameters,
      rule_inputs_snapshot: evaluated[:rule_inputs_snapshot],
      precision: definition.precision,
      time_zone: definition.time_zone,
      cardinality: definition.cardinality,
      coverage_snapshot:,
      calculated_on: evaluated[:calculated_on],
      calculated_at: evaluated[:calculated_at],
      materialization_key: key,
      predecessor_occurrence: predecessor,
      actor: @actor,
      materialized_at: @at
    )
    if predecessor&.current? && !predecessor.elapsed?(at: @at)
      predecessor.mark_superseded!(at: @at)
    end
    RefreshSupplierDeadlineProjection.call(occurrence:, at: @at)
    occurrence
  rescue ActiveRecord::RecordNotUnique
    SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version_id: @version.id,
      materialization_key: key
    )
  end

  def find_predecessor_occurrence(definition)
    return unless definition.copied_from_id

    SupplierDeadlineOccurrence
      .where(
        agency_id: @agency.id,
        supplier_arrangement_id: @arrangement.id,
        supplier_deadline_definition_id: definition.copied_from_id
      )
      .where(superseded_at: nil)
      .order(:materialized_at, :id)
      .lock
      .last
  end
end
