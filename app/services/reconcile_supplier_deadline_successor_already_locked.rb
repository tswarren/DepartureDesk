# frozen_string_literal: true

# Internal successor-activation helper. Caller must already hold the exact-version lock graph.
class ReconcileSupplierDeadlineSuccessorAlreadyLocked
  # Actionable requirement identity only. Display copy and warning timing may change
  # without reopening a terminal predecessor commitment.
  MATERIAL_DEFINITION_ATTRS = %w[
    deadline_type other_label kind rule_shape rule_parameters precision time_zone
    cardinality
  ].freeze

  MATERIAL_LINE_ATTRS = %w[
    authority_shape committed_supplier_id fixed_quantity quantity_basis
    currency supplier_cost_source_id supplier_cost_definition_id supplier_cost_component_id
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

    successor_defs_by_copied_from = @version.supplier_deadline_definitions
      .where.not(copied_from_id: nil)
      .index_by(&:copied_from_id)
    successor_lines_by_copied_from = @version.supplier_deadline_commitment_definition_lines
      .where.not(copied_from_id: nil)
      .index_by(&:copied_from_id)

    open_predecessor_commitments.each do |commitment|
      line = commitment.supplier_deadline_commitment_definition_line
      next if line.nil?

      successor_definition = successor_defs_by_copied_from[line.supplier_deadline_definition_id]
      successor_line = successor_lines_by_copied_from[line.id]
      next if successor_definition && successor_line

      raise AgencyCommand::Error.new(
        "Resolve open Deadline commitments for removed successor definitions before activation.",
        code: :invalid_state
      )
    end
  end

  # Terminal + unchanged lineage must not reopen. All other cases open (added, changed, or
  # open predecessor that will be superseded after the successor opens).
  def skip_open?(line)
    return false unless @predecessor_version
    return false if line.copied_from_id.blank?

    predecessor_line = predecessor_line_for(line)
    return false unless predecessor_line
    return false if open_commitment_for_line(predecessor_line)
    return false if materially_changed?(line, predecessor_line)

    terminal_commitment_exists_for_line?(predecessor_line)
  end

  def after_open!(successor_commitment, line)
    return unless @predecessor_version
    return if line.copied_from_id.blank?

    predecessor_line = predecessor_line_for(line)
    return unless predecessor_line

    predecessor_commitment = open_commitment_for_line(predecessor_line)
    return unless predecessor_commitment

    dispose_superseded!(predecessor_commitment, replacement: successor_commitment)
  end

  private

  def predecessor_line_for(line)
    SupplierDeadlineCommitmentDefinitionLine.find_by(
      id: line.copied_from_id,
      supplier_arrangement_version_id: @predecessor_version.id
    )
  end

  def open_predecessor_commitments
    @open_predecessor_commitments ||= begin
      commitments = @arrangement.supplier_commitments
        .where(
          opening_kind: "deadline_requirement",
          supplier_arrangement_version_id: @predecessor_version.id
        )
        .includes(
          :supplier_deadline_commitment_definition_line,
          supplier_commitment_dispositions: :supplier_commitment_reopening
        )
        .order(:id)
        .lock
        .to_a
      commitments.select(&:open_state?)
    end
  end

  def open_commitment_for_line(line)
    open_predecessor_commitments.find do |commitment|
      commitment.supplier_deadline_commitment_definition_line_id == line.id
    end
  end

  def terminal_commitment_exists_for_line?(line)
    commitments = @arrangement.supplier_commitments
      .where(
        opening_kind: "deadline_requirement",
        supplier_arrangement_version_id: @predecessor_version.id,
        supplier_deadline_commitment_definition_line_id: line.id
      )
      .includes(supplier_commitment_dispositions: :supplier_commitment_reopening)
    commitments.any? { |commitment| !commitment.open_state? }
  end

  def materially_changed?(successor_line, predecessor_line)
    successor_definition = successor_line.supplier_deadline_definition
    predecessor_definition = predecessor_line.supplier_deadline_definition

    MATERIAL_DEFINITION_ATTRS.any? do |attr|
      normalize_compare(successor_definition.public_send(attr)) !=
        normalize_compare(predecessor_definition.public_send(attr))
    end || coverage_fingerprint(successor_definition) != coverage_fingerprint(predecessor_definition) ||
      MATERIAL_LINE_ATTRS.any? do |attr|
        normalize_line_attr(successor_line, attr) != normalize_line_attr(predecessor_line, attr)
      end
  end

  def normalize_compare(value)
    case value
    when Hash then value.deep_stringify_keys
    when Array then value.map { |entry| normalize_compare(entry) }
    else value
    end
  end

  def normalize_line_attr(line, attr)
    value = line.public_send(attr)
    return value if value.blank?

    case attr
    when "supplier_cost_source_id"
      record = SupplierCostSource.find_by(id: value)
      record&.copied_from_id || record&.id
    when "supplier_cost_definition_id"
      record = SupplierCostDefinition.find_by(id: value)
      record&.copied_from_id || record&.id
    when "supplier_cost_component_id"
      record = SupplierCostComponent.find_by(id: value)
      record&.copied_from_id || record&.id
    else
      value
    end
  end

  def coverage_fingerprint(definition)
    definition.supplier_deadline_definition_coverage_links.order(:position, :id).map do |link|
      [
        link.arrangement_item_id, link.service_occurrence_id,
        link.supplier_resource_id, link.capacity_pool_id
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
