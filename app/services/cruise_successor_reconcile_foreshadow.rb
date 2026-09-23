# frozen_string_literal: true

# Read-only foreshadow of successor activation reconcile outcomes.
# Mirrors ReconcileSupplier*AlreadyLocked material-change notions without locking or writing.
class CruiseSuccessorReconcileForeshadow
  FORESHADOW_LABELS = {
    unchanged: "Unchanged — will not reopen on successor activation (not yet applied)",
    will_supersede: "Will supersede the open governing commitment on successor activation (not yet applied)",
    will_open: "Will open a commitment on successor activation (not yet applied)",
    blocks_open_commitment:
      "Blocks successor activation until the open governing commitment is resolved (not yet applied)"
  }.freeze

  def self.label_for(code)
    FORESHADOW_LABELS.fetch(code.to_sym) { code.to_s.humanize }
  end

  def self.removal_blockers(arrangement:, version:, predecessor_version:)
    return [] unless predecessor_version

    blockers = []

    successor_deadline_ids = version.supplier_deadline_definitions
      .where.not(copied_from_id: nil)
      .pluck(:copied_from_id)
      .to_set
    successor_deadline_line_ids = version.supplier_deadline_commitment_definition_lines
      .where.not(copied_from_id: nil)
      .pluck(:copied_from_id)
      .to_set

    open_deadline_commitments(arrangement, predecessor_version).each do |commitment|
      line = commitment.supplier_deadline_commitment_definition_line
      next if line.nil?
      next if successor_deadline_ids.include?(line.supplier_deadline_definition_id) &&
        successor_deadline_line_ids.include?(line.id)

      blockers <<
        "Resolve open Deadline commitments for removed successor definitions before activation."
      break
    end

    successor_deposit_ids = version.supplier_deposit_requirement_definitions
      .where.not(copied_from_id: nil)
      .pluck(:copied_from_id)
      .to_set

    open_deposit_commitments(arrangement, predecessor_version).each do |commitment|
      tranche = commitment.supplier_deposit_requirement_tranche
      next if tranche.nil?
      next if successor_deposit_ids.include?(tranche.supplier_deposit_requirement_definition_id)

      blockers <<
        "Resolve open Deposit commitments for removed successor definitions before activation."
      break
    end

    blockers
  end

  def self.for_deadline_definition(definition:, arrangement:, version:, predecessor_version:, at: Time.current)
    return :will_open unless predecessor_version
    return :will_open if definition.copied_from_id.blank?
    return :will_open unless definition.actionable?

    reconciler = ReconcileSupplierDeadlineSuccessorAlreadyLocked.new(
      agency: arrangement.agency,
      actor: nil,
      arrangement: arrangement,
      version: version,
      predecessor_version: predecessor_version,
      at: at
    )

    lines = definition.supplier_deadline_commitment_definition_lines.order(:position, :id).to_a
    return :will_open if lines.empty?

    codes = lines.map { |line| foreshadow_deadline_line(line, arrangement, predecessor_version, reconciler) }
    return :blocks_open_commitment if codes.include?(:blocks_open_commitment)
    return :will_supersede if codes.include?(:will_supersede)
    return :unchanged if codes.all? { |code| code == :unchanged }

    :will_open
  end

  def self.for_deposit_definition(definition:, arrangement:, version:, predecessor_version:, at: Time.current)
    return :will_open unless predecessor_version
    return :will_open if definition.copied_from_id.blank?

    reconciler = ReconcileSupplierDepositSuccessorAlreadyLocked.new(
      agency: arrangement.agency,
      actor: nil,
      arrangement: arrangement,
      version: version,
      predecessor_version: predecessor_version,
      at: at
    )

    predecessor = SupplierDepositRequirementDefinition.find_by(
      id: definition.copied_from_id,
      supplier_arrangement_version_id: predecessor_version.id
    )
    return :will_open unless predecessor

    open = open_deposit_commitments(arrangement, predecessor_version).find { |commitment|
      commitment.supplier_deposit_requirement_tranche&.supplier_deposit_requirement_definition_id ==
        predecessor.id
    }
    return :will_supersede if open
    return :unchanged if reconciler.skip_open?(definition)

    :will_open
  end

  def self.foreshadow_deadline_line(line, arrangement, predecessor_version, reconciler)
    return :will_open if line.copied_from_id.blank?

    predecessor_line = SupplierDeadlineCommitmentDefinitionLine.find_by(
      id: line.copied_from_id,
      supplier_arrangement_version_id: predecessor_version.id
    )
    return :will_open unless predecessor_line

    open = open_deadline_commitments(arrangement, predecessor_version).find { |commitment|
      commitment.supplier_deadline_commitment_definition_line_id == predecessor_line.id
    }
    return :will_supersede if open
    return :unchanged if reconciler.skip_open?(line)

    :will_open
  end
  private_class_method :foreshadow_deadline_line

  def self.open_deadline_commitments(arrangement, predecessor_version)
    arrangement.supplier_commitments
      .where(
        opening_kind: "deadline_requirement",
        supplier_arrangement_version_id: predecessor_version.id
      )
      .includes(
        :supplier_deadline_commitment_definition_line,
        supplier_commitment_dispositions: :supplier_commitment_reopening
      )
      .select(&:open_state?)
  end
  private_class_method :open_deadline_commitments

  def self.open_deposit_commitments(arrangement, predecessor_version)
    arrangement.supplier_commitments
      .where(
        opening_kind: "deposit_requirement",
        supplier_arrangement_version_id: predecessor_version.id
      )
      .includes(
        :supplier_deposit_requirement_tranche,
        supplier_commitment_dispositions: :supplier_commitment_reopening
      )
      .select(&:open_state?)
  end
  private_class_method :open_deposit_commitments
end
