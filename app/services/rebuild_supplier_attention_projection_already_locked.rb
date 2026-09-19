# frozen_string_literal: true

require "digest"

# Rebuilds Arrangement Needs-attention findings from authoritative sources.
# Callers must already hold Agency and Arrangement locks.
class RebuildSupplierAttentionProjectionAlreadyLocked
  FindingDraft = Data.define(
    :detector_key, :action_group, :severity, :source_kind, :source_id,
    :required_action, :reason, :consequence_summary, :primary_path,
    :attention_at, :overdue_at, :source_fingerprint
  )

  def initialize(agency:, arrangement:, version: nil, at: Time.current)
    @agency = agency
    @arrangement = arrangement
    @version = version
    @at = at
  end

  def call
    version = resolve_version!
    lock_existing!(version)

    drafts = []
    drafts.concat(commitment_deadline_findings(version))
    drafts.concat(deadline_materialization_findings(version))
    drafts.concat(deposit_calculation_findings(version))
    drafts.concat(exposure_incomplete_findings(version))
    drafts.concat(unresolved_reservation_findings(version))
    drafts.concat(capacity_findings(version))

    replace_findings!(version, drafts)
    SupplierAttentionFinding.where(supplier_arrangement_id: @arrangement.id).order(:id)
  end

  private

  def resolve_version!
    version = @version ||
      @arrangement.governing_version ||
      @arrangement.versions.order(version_number: :desc, id: :desc).first
    if version.nil?
      raise AgencyCommand::Error.new(
        "Arrangement has no version for attention rebuild.",
        code: :invalid_state
      )
    end

    @agency.supplier_arrangement_versions.lock.find(version.id)
  end

  def lock_existing!(version)
    SupplierAttentionFinding.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id
    ).order(:detector_key, :source_kind, :source_id, :id).lock.load
  end

  def commitment_deadline_findings(version)
    commitments = SupplierCommitment.with_current_disposition_state.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id
    ).order(:id).to_a.select(&:open_state?)

    occurrence_ids = commitments.filter_map(&:supplier_deadline_occurrence_id)
    deposit_ids = commitments.filter_map(&:supplier_deposit_requirement_tranche_id)
    tranches = if deposit_ids.any?
      SupplierDepositRequirementTranche.where(id: deposit_ids).includes(:governing_deadline_occurrence).index_by(&:id)
    else
      {}
    end
    occurrences = load_occurrences_for(occurrence_ids, tranches)
    projections = SupplierDeadlineProjection.where(
      supplier_deadline_occurrence_id: occurrences.keys
    ).index_by(&:supplier_deadline_occurrence_id)

    commitments.filter_map do |commitment|
      occurrence = governing_occurrence_for(commitment, occurrences, tranches)
      projection = occurrence && projections[occurrence.id]
      classify_commitment_finding(commitment, occurrence, projection)
    end
  end

  def load_occurrences_for(occurrence_ids, tranches)
    ids = occurrence_ids + tranches.values.filter_map(&:governing_deadline_occurrence_id)
    return {} if ids.empty?

    SupplierDeadlineOccurrence.where(id: ids.uniq).index_by(&:id)
  end

  def governing_occurrence_for(commitment, occurrences, tranches)
    if commitment.supplier_deadline_occurrence_id.present?
      return occurrences[commitment.supplier_deadline_occurrence_id]
    end
    if commitment.deposit_requirement?
      tranche = tranches[commitment.supplier_deposit_requirement_tranche_id]
      return occurrences[tranche.governing_deadline_occurrence_id] if tranche&.governing_deadline_occurrence_id
    end

    nil
  end

  def classify_commitment_finding(commitment, occurrence, projection)
    if occurrence.nil? || occurrence.superseded_at.present?
      return FindingDraft.new(
        detector_key: "open_commitment_without_future_deadline",
        action_group: "dispose_or_satisfy_commitment",
        severity: "attention",
        source_kind: "supplier_commitment",
        source_id: commitment.id,
        required_action: "Dispose or satisfy the open commitment",
        reason: "Open commitment has no future actionable Deadline",
        consequence_summary: "Supplier planning remains incomplete until this opening is resolved",
        primary_path: "commitments",
        attention_at: commitment.opened_at,
        overdue_at: nil,
        source_fingerprint: fingerprint("commitment", commitment.id, "no_deadline", commitment.opened_at)
      )
    end

    overdue_at = projection&.overdue_at || occurrence_overdue_at(occurrence)
    warning_at = projection&.warning_starts_at
    due_boundary = occurrence.date_only? ? (overdue_at - 1.day) : occurrence.calculated_at
    attention_at = warning_at || due_boundary || commitment.opened_at
    # Persist before the warning/due boundary so read-time visibility can reveal the
    # finding without waiting for catch-up. Overdue labeling uses overdue_at on read.
    severity = overdue_at.present? && @at >= overdue_at ? "overdue" : "attention"

    FindingDraft.new(
      detector_key: "actionable_commitment_due_soon",
      action_group: "dispose_or_satisfy_commitment",
      severity:,
      source_kind: "supplier_commitment",
      source_id: commitment.id,
      required_action: severity == "overdue" ? "Resolve the overdue commitment" : "Act on the due commitment",
      reason: severity == "overdue" ?
        "Actionable commitment is overdue" :
        "Actionable commitment is due soon",
      consequence_summary: severity == "overdue" ?
        "Supplier deadline has elapsed while the commitment remains open" :
        "Deadline warning or due window applies to this open commitment",
      primary_path: "commitments",
      attention_at:,
      overdue_at:,
      source_fingerprint: fingerprint(
        "commitment", commitment.id, "due_soon", attention_at, overdue_at
      )
    )
  end

  def occurrence_overdue_at(occurrence)
    zone = ActiveSupport::TimeZone[occurrence.time_zone] || Time.find_zone!("UTC")
    if occurrence.date_only?
      due_on = occurrence.calculated_on
      zone.local(due_on.year, due_on.month, due_on.day) + 1.day
    else
      occurrence.calculated_at
    end
  end

  def deadline_materialization_findings(version)
    return [] unless version.activated? || version.superseded?

    definitions = version.supplier_deadline_definitions.order(:position, :id).to_a
    return [] if definitions.empty?

    occurrences_by_definition = SupplierDeadlineOccurrence.where(
      supplier_arrangement_version_id: version.id,
      superseded_at: nil
    ).where.not(supplier_deadline_definition_id: nil)
      .order(:materialized_at, :id)
      .group_by(&:supplier_deadline_definition_id)

    definitions.filter_map do |definition|
      next if occurrences_by_definition[definition.id].present?

      FindingDraft.new(
        detector_key: "deadline_materialization_incomplete",
        action_group: "resolve_deadline",
        severity: "blocking",
        source_kind: "supplier_deadline_definition",
        source_id: definition.id,
        required_action: "Complete Deadline materialization",
        reason: "Deadline definition has no current occurrence",
        consequence_summary: "Planning cannot rely on this Deadline until it materializes",
        primary_path: "deadlines",
        attention_at: version.activated_at || @at,
        overdue_at: nil,
        source_fingerprint: fingerprint("deadline_def", definition.id, "missing_occurrence")
      )
    end
  end

  def deposit_calculation_findings(version)
    return [] unless version.activated? || version.superseded?

    definitions = version.supplier_deposit_requirement_definitions.order(:position, :id).to_a
    return [] if definitions.empty?

    tranched = SupplierDepositRequirementTranche.where(
      supplier_arrangement_version_id: version.id
    ).pluck(:supplier_deposit_requirement_definition_id).to_set

    definitions.filter_map do |definition|
      next if tranched.include?(definition.id)
      next if deposit_intentionally_unmaterialized?(definition, version)

      incomplete = deposit_incomplete_message(definition, version)
      next unless incomplete

      FindingDraft.new(
        detector_key: "deposit_calculation_incomplete",
        action_group: "complete_deposit_inputs",
        severity: "blocking",
        source_kind: "supplier_deposit_requirement_definition",
        source_id: definition.id,
        required_action: "Complete deposit calculation inputs",
        reason: incomplete,
        consequence_summary: "Deposit Requirement cannot materialize until calculation inputs are complete",
        primary_path: "deposits",
        attention_at: version.activated_at || @at,
        overdue_at: nil,
        source_fingerprint: fingerprint("deposit_def", definition.id, incomplete)
      )
    end
  end

  # Mirrors ReconcileSupplierDepositSuccessorAlreadyLocked#skip_open?: an unchanged
  # successor deposit whose predecessor commitment is already terminal is intentionally
  # left without a new tranche.
  def deposit_intentionally_unmaterialized?(definition, version)
    predecessor_version = version.copied_from
    return false if predecessor_version.nil?

    ReconcileSupplierDepositSuccessorAlreadyLocked.new(
      agency: @agency,
      actor: AgencyUser.new,
      arrangement: @arrangement,
      version:,
      predecessor_version:
    ).skip_open?(definition)
  end

  def deposit_incomplete_message(definition, version)
    SupplierDepositAmountEvaluator.call(
      definition:,
      arrangement: @arrangement,
      version:
    )
    "Deposit Requirement has not materialized"
  rescue SupplierDepositAmountEvaluator::IncompleteCalculation => error
    error.message.to_s.truncate(240)
  rescue StandardError
    "Deposit Requirement calculation failed"
  end

  def exposure_incomplete_findings(version)
    SupplierExposureComponent.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id,
      supplier_arrangement_version_id: version.id,
      completeness: %w[incomplete unknown]
    ).order(:source_kind, :source_id, :id).map do |component|
      FindingDraft.new(
        detector_key: "exposure_incomplete",
        action_group: "inspect_exposure",
        severity: "attention",
        source_kind: "supplier_exposure_component",
        source_id: component.id,
        required_action: "Inspect incomplete exposure",
        reason: "Exposure component is #{component.completeness}",
        consequence_summary: "Qualified exposure cannot be treated as known until inputs are complete",
        primary_path: "exposure",
        attention_at: component.effective_at || component.rebuilt_at || @at,
        overdue_at: nil,
        source_fingerprint: fingerprint(
          "exposure", component.id, component.completeness, component.source_fingerprint
        )
      )
    end
  end

  def unresolved_reservation_findings(version)
    @arrangement.supplier_reservations.order(:id).filter_map do |reservation|
      rows = UnresolvedReservationCommitmentTriggers.call(
        agency: @agency, reservation:
      )
      next if rows.empty?

      trigger_keys = rows.map { |row| [ row.confirmation.id, row.trigger.id ] }.sort
      reason = if rows.size == 1
        "Confirmed reservation scope still lacks its confirmation-triggered commitment"
      else
        "#{rows.size} confirmed reservation scopes still lack confirmation-triggered commitments"
      end

      FindingDraft.new(
        detector_key: "unresolved_reservation_response_scope",
        action_group: "resolve_reservation_response",
        severity: "attention",
        source_kind: "supplier_reservation",
        source_id: reservation.id,
        required_action: "Resolve reservation confirmation trigger",
        reason:,
        consequence_summary: "Confirmation evidence exists without the expected commitment opening",
        primary_path: "commitments",
        attention_at: rows.map { |row| row.confirmation.recorded_at }.min,
        overdue_at: nil,
        source_fingerprint: fingerprint("reservation_unresolved", reservation.id, *trigger_keys.flatten)
      )
    end
  end

  def capacity_findings(version)
    drafts = []

    reconciliations = CapacityReconciliation.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id
    ).order(:id).includes(:resolutions, :capacity_events)
    reconciliations.each do |reconciliation|
      next unless reconciliation.open_discrepancy?

      drafts << FindingDraft.new(
        detector_key: "capacity_override_or_discrepancy",
        action_group: "review_capacity",
        severity: reconciliation.override? ? "blocking" : "attention",
        source_kind: "capacity_reconciliation",
        source_id: reconciliation.id,
        required_action: "Resolve capacity discrepancy",
        reason: reconciliation.override? ?
          "Capacity reconciliation relies on an accepted override" :
          "Capacity ledger has an open discrepancy",
        consequence_summary: "Effective capacity cannot be trusted until the discrepancy is resolved",
        primary_path: "capacity",
        attention_at: reconciliation.recorded_at,
        overdue_at: nil,
        source_fingerprint: fingerprint(
          "reconciliation", reconciliation.id, reconciliation.variance, reconciliation.override?
        )
      )
    end

    version.capacity_pool_definitions.where(override: true).order(:id).each do |definition|
      drafts << FindingDraft.new(
        detector_key: "capacity_override_or_discrepancy",
        action_group: "review_capacity",
        severity: "attention",
        source_kind: "capacity_pool",
        source_id: definition.capacity_pool_id,
        required_action: "Review capacity override",
        reason: "Capacity pool relies on an accepted override",
        consequence_summary: "Override remains part of effective capacity planning state",
        primary_path: "capacity",
        attention_at: definition.updated_at || definition.created_at,
        overdue_at: nil,
        source_fingerprint: fingerprint("pool_override", definition.capacity_pool_id, definition.id)
      )
    end

    drafts
  end

  def replace_findings!(version, drafts)
    desired = drafts.index_by { |draft| [ draft.detector_key, draft.source_kind, draft.source_id ] }
    existing = SupplierAttentionFinding.where(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id
    ).index_by { |row| [ row.detector_key, row.source_kind, row.source_id ] }

    (existing.keys - desired.keys).each do |key|
      existing[key].destroy!
    end

    desired.each do |key, draft|
      attrs = {
        agency_id: @agency.id,
        departure_id: @arrangement.departure_id,
        supplier_arrangement_id: @arrangement.id,
        supplier_arrangement_version_id: version.id,
        detector_key: draft.detector_key,
        action_group: draft.action_group,
        severity: draft.severity,
        source_kind: draft.source_kind,
        source_id: draft.source_id,
        required_action: draft.required_action,
        reason: draft.reason,
        consequence_summary: draft.consequence_summary,
        primary_path: draft.primary_path,
        attention_at: draft.attention_at,
        overdue_at: draft.overdue_at,
        rebuilt_at: @at,
        source_fingerprint: draft.source_fingerprint
      }
      row = existing[key]
      if row
        row.update!(attrs.except(
          :agency_id, :departure_id, :supplier_arrangement_id, :source_kind, :source_id, :detector_key
        ))
      else
        SupplierAttentionFinding.create!(attrs)
      end
    end
  end

  def fingerprint(*parts)
    Digest::SHA256.hexdigest(parts.map(&:to_s).join("|"))
  end
end
