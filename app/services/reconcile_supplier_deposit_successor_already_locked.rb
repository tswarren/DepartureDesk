# frozen_string_literal: true

# Internal successor-activation helper. Caller must already hold the exact-version lock graph.
class ReconcileSupplierDepositSuccessorAlreadyLocked
  MATERIAL_DEFINITION_ATTRS = %w[
    amount_shape fixed_amount_minor_units rate_minor_units quantity_basis explicit_quantity
    percentage rounding_scope target_amount_minor_units currency rule_shape rule_parameters
    precision time_zone
  ].freeze

  def initialize(agency:, actor:, arrangement:, version:, predecessor_version:, at: Time.current)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @predecessor_version = predecessor_version
    @at = at
  end

  def assert_removals_resolved!
    return unless @predecessor_version

    successor_defs_by_copied_from = @version.supplier_deposit_requirement_definitions
      .where.not(copied_from_id: nil)
      .index_by(&:copied_from_id)

    open_predecessor_commitments.each do |commitment|
      tranche = commitment.supplier_deposit_requirement_tranche
      next if tranche.nil?

      next if successor_defs_by_copied_from[tranche.supplier_deposit_requirement_definition_id]

      raise AgencyCommand::Error.new(
        "Resolve open Deposit commitments for removed successor definitions before activation.",
        code: :invalid_state
      )
    end
  end

  def skip_open?(definition)
    return false unless @predecessor_version
    return false if definition.copied_from_id.blank?

    predecessor = predecessor_definition_for(definition)
    return false unless predecessor
    return false if open_commitment_for_definition(predecessor)
    return false if materially_changed?(definition, predecessor)

    terminal_commitment_exists_for_definition?(predecessor)
  end

  def after_open!(successor_commitment, definition)
    return unless @predecessor_version
    return if definition.copied_from_id.blank?

    predecessor = predecessor_definition_for(definition)
    return unless predecessor

    predecessor_commitment = open_commitment_for_definition(predecessor)
    return unless predecessor_commitment

    dispose_superseded!(predecessor_commitment, replacement: successor_commitment)
  end

  private

  def predecessor_definition_for(definition)
    SupplierDepositRequirementDefinition.find_by(
      id: definition.copied_from_id,
      supplier_arrangement_version_id: @predecessor_version.id
    )
  end

  def open_predecessor_commitments
    @open_predecessor_commitments ||= begin
      commitments = @arrangement.supplier_commitments
        .where(
          opening_kind: "deposit_requirement",
          supplier_arrangement_version_id: @predecessor_version.id
        )
        .includes(
          :supplier_deposit_requirement_tranche,
          supplier_commitment_dispositions: :supplier_commitment_reopening
        )
        .order(:id)
        .lock
        .to_a
      commitments.select(&:open_state?)
    end
  end

  def open_commitment_for_definition(definition)
    open_predecessor_commitments.find do |commitment|
      commitment.supplier_deposit_requirement_tranche&.supplier_deposit_requirement_definition_id ==
        definition.id
    end
  end

  def terminal_commitment_exists_for_definition?(definition)
    commitments = @arrangement.supplier_commitments
      .where(
        opening_kind: "deposit_requirement",
        supplier_arrangement_version_id: @predecessor_version.id
      )
      .joins(:supplier_deposit_requirement_tranche)
      .where(
        supplier_deposit_requirement_tranches: {
          supplier_deposit_requirement_definition_id: definition.id
        }
      )
      .includes(supplier_commitment_dispositions: :supplier_commitment_reopening)
    commitments.any? { |commitment| !commitment.open_state? }
  end

  def materially_changed?(successor, predecessor)
    MATERIAL_DEFINITION_ATTRS.any? do |attr|
      normalize_compare(successor.public_send(attr)) != normalize_compare(predecessor.public_send(attr))
    end || coverage_fingerprint(successor) != coverage_fingerprint(predecessor) ||
      cost_fingerprint(successor) != cost_fingerprint(predecessor)
  end

  def normalize_compare(value)
    case value
    when Hash then value.deep_stringify_keys
    when Array then value.map { |entry| normalize_compare(entry) }
    when BigDecimal then value.to_s("F")
    else value
    end
  end

  def coverage_fingerprint(definition)
    definition.supplier_deposit_requirement_definition_coverage_links.order(:position, :id).map do |link|
      [
        link.arrangement_item_id, link.service_occurrence_id,
        link.supplier_resource_id, link.capacity_pool_id
      ]
    end
  end

  def cost_fingerprint(definition)
    definition.supplier_deposit_requirement_definition_cost_links.order(:position, :id).map do |link|
      [
        link.supplier_cost_source_id, link.supplier_cost_definition_id,
        link.supplier_cost_component_id
      ]
    end
  end

  def dispose_superseded!(commitment, replacement:)
    now = @at
    SupplierCommitmentDisposition.create!(
      agency_id: commitment.agency_id,
      departure_id: commitment.departure_id,
      supplier_arrangement_id: commitment.supplier_arrangement_id,
      supplier_arrangement_version_id: commitment.supplier_arrangement_version_id,
      supplier_commitment: commitment,
      outcome: "superseded",
      replacement_supplier_commitment: replacement,
      actor: @actor,
      occurred_at: now,
      recorded_at: now,
      accepted_risk_acknowledged: false
    )
  end
end
