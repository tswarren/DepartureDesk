# frozen_string_literal: true

# Write-free Stop D activation consequence preview for the typed Cruise workspace.
# Advisory only: creates no occurrences, tranches, commitments, audits, or idempotency rows.
class PreviewCruiseDepositsAndDeadlinesActivation
  ActivationRow = Data.define(
    :kind,
    :definition_id,
    :display_name,
    :amount_sentence,
    :pending_reasons,
    :due_sentence,
    :time_zone,
    :coverage_summary,
    :will_open_commitment?,
    :elapsed_acknowledgment_required?,
    :blocker,
    :editor_anchor
  )

  UniqueBlocker = Data.define(
    :message,
    :corrective_path,
    :corrective_label,
    :editor_anchor,
    :kind,
    :definition_id
  )

  Result = Data.define(
    :status,
    :stale?,
    :version_lock_version,
    :rows,
    :elapsed_acknowledgment_required?,
    :blockers,
    :unique_blockers,
    :activation_path
  )

  CABIN_QUANTITY_MESSAGE = /
    proposed\s+opening\s+quantity|
    capacity[-\s]?pool\s+quantity|
    retained\s+capacity|
    established\s+capacity|
    capacity\s+projection
  /ix

  def self.call(**)
    new(**).call
  end

  def initialize(
    agency:,
    arrangement:,
    version:,
    version_lock_version: nil,
    at: Time.current
  )
    @agency = agency
    @arrangement = arrangement
    @version = version
    @version_lock_version = version_lock_version
    @at = at
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    version = arrangement.versions.find(@version.id)
    departure = arrangement.departure

    if @version_lock_version.present? && version.lock_version != Integer(@version_lock_version)
      message = "This Arrangement version changed. Refresh before continuing."
      return Result.new(
        status: "stale",
        stale?: true,
        version_lock_version: version.lock_version,
        rows: [],
        elapsed_acknowledgment_required?: false,
        blockers: [ message ],
        unique_blockers: [
          UniqueBlocker.new(
            message: message,
            corrective_path: deposits_and_deadlines_path(departure, arrangement),
            corrective_label: "Refresh deposits and deadlines",
            editor_anchor: nil,
            kind: nil,
            definition_id: nil
          )
        ],
        activation_path: activation_path_for(departure, arrangement)
      )
    end

    unless version.draft?
      message = "Activation preview is available only for draft Arrangement versions."
      return Result.new(
        status: "invalid",
        stale?: false,
        version_lock_version: version.lock_version,
        rows: [],
        elapsed_acknowledgment_required?: false,
        blockers: [ message ],
        unique_blockers: [
          UniqueBlocker.new(
            message: message,
            corrective_path: deposits_and_deadlines_path(departure, arrangement),
            corrective_label: "Open deposits and deadlines",
            editor_anchor: nil,
            kind: nil,
            definition_id: nil
          )
        ],
        activation_path: activation_path_for(departure, arrangement)
      )
    end

    cruise_shape = DetectCruiseArrangementShape.new(
      agency: @agency,
      arrangement: arrangement,
      version: version
    ).call

    predecessor = version.copied_from
    deadline_reconciler = predecessor && ReconcileSupplierDeadlineSuccessorAlreadyLocked.new(
      agency: @agency,
      actor: nil,
      arrangement: arrangement,
      version: version,
      predecessor_version: predecessor,
      at: @at
    )
    deposit_reconciler = predecessor && ReconcileSupplierDepositSuccessorAlreadyLocked.new(
      agency: @agency,
      actor: nil,
      arrangement: arrangement,
      version: version,
      predecessor_version: predecessor,
      at: @at
    )

    rows = []
    blockers = []

    removal_blockers = CruiseSuccessorReconcileForeshadow.removal_blockers(
      arrangement: arrangement,
      version: version,
      predecessor_version: predecessor
    )
    blockers.concat(removal_blockers)

    version.supplier_deposit_requirement_definitions
      .includes(
        :supplier_deposit_requirement_definition_coverage_links,
        :supplier_deposit_requirement_definition_contributor_links,
        :supplier_deposit_requirement_definition_cost_links
      )
      .order(:position, :id)
      .each do |definition|
        rows << deposit_row(
          definition:,
          arrangement:,
          version:,
          departure:,
          cruise_shape:,
          reconciler: deposit_reconciler
        )
      end

    version.supplier_deadline_definitions
      .includes(
        :supplier_deadline_definition_coverage_links,
        :supplier_deadline_commitment_definition_lines
      )
      .order(:position, :id)
      .each do |definition|
        rows << deadline_row(
          definition:,
          departure:,
          cruise_shape:,
          reconciler: deadline_reconciler
        )
      end

    rows.each do |row|
      blockers << row.blocker if row.blocker.present?
    end

    unique_blockers = build_unique_blockers(
      removal_messages: removal_blockers,
      rows: rows,
      departure: departure,
      arrangement: arrangement
    )

    Result.new(
      status: blockers.any? ? "blocked" : "ready",
      stale?: false,
      version_lock_version: version.lock_version,
      rows: rows,
      elapsed_acknowledgment_required?: rows.any?(&:elapsed_acknowledgment_required?),
      blockers: blockers.uniq,
      unique_blockers: unique_blockers,
      activation_path: activation_path_for(departure, arrangement)
    )
  end

  private

  def deposit_row(definition:, arrangement:, version:, departure:, cruise_shape:, reconciler:)
    amount_sentence = nil
    pending_reasons = []
    blocker = nil
    due_sentence = nil
    elapsed = false

    begin
      evaluated_amount = SupplierDepositAmountEvaluator.call(
        definition:,
        version:,
        arrangement:,
        mode: :preview,
        at: @at
      )
      amount_sentence = Money.new(
        evaluated_amount[:amount_minor_units],
        definition.currency.presence || departure.operating_currency
      ).format
    rescue SupplierDepositAmountEvaluator::IncompleteCalculation => error
      pending_reasons = [ error.message ]
      blocker = error.message
    end

    begin
      evaluated = SupplierDeadlineRuleEvaluator.call(
        definition:,
        departure:,
        at: @at,
        allow_milestones: true,
        unresolved_milestone_policy: :use_other_arm
      )
      provisional = SupplierDeadlineOccurrence.new(
        precision: definition.precision,
        time_zone: definition.time_zone,
        calculated_on: evaluated[:calculated_on],
        calculated_at: evaluated[:calculated_at]
      )
      due_sentence = due_sentence_for(provisional, definition.time_zone)
      elapsed = provisional.elapsed?(at: @at)
    rescue StandardError => error
      blocker ||= error.message
      pending_reasons << error.message unless pending_reasons.include?(error.message)
    end

    will_open = reconciler.nil? || !reconciler.skip_open?(definition)

    ActivationRow.new(
      kind: "deposit",
      definition_id: definition.id,
      display_name: definition.description.presence || "Deposit requirement",
      amount_sentence: amount_sentence,
      pending_reasons: pending_reasons,
      due_sentence: due_sentence,
      time_zone: definition.time_zone,
      coverage_summary: CruiseDepositTemplateSupport.coverage_summary(definition, cruise_shape),
      will_open_commitment?: will_open,
      elapsed_acknowledgment_required?: elapsed,
      blocker: blocker,
      editor_anchor: "#cruise-deposit-#{definition.id}"
    )
  end

  def deadline_row(definition:, departure:, cruise_shape:, reconciler:)
    due_sentence = nil
    elapsed = false
    blocker = nil
    pending_reasons = []

    begin
      evaluated = SupplierDeadlineRuleEvaluator.call(
        definition:,
        departure:,
        at: @at
      )
      provisional = SupplierDeadlineOccurrence.new(
        precision: definition.precision,
        time_zone: definition.time_zone,
        calculated_on: evaluated[:calculated_on],
        calculated_at: evaluated[:calculated_at]
      )
      due_sentence = due_sentence_for(provisional, definition.time_zone)
      elapsed = provisional.elapsed?(at: @at)
    rescue StandardError => error
      blocker = error.message
      pending_reasons = [ error.message ]
    end

    will_open = false
    if definition.actionable?
      will_open = definition.supplier_deadline_commitment_definition_lines.any? { |line|
        reconciler.nil? || !reconciler.skip_open?(line)
      }
    end

    ActivationRow.new(
      kind: "deadline",
      definition_id: definition.id,
      display_name: definition.display_label,
      amount_sentence: nil,
      pending_reasons: pending_reasons,
      due_sentence: due_sentence,
      time_zone: definition.time_zone,
      coverage_summary: deadline_coverage_summary(definition, cruise_shape),
      will_open_commitment?: will_open,
      elapsed_acknowledgment_required?: elapsed,
      blocker: blocker,
      editor_anchor: "#cruise-deadline-#{definition.id}"
    )
  end

  def build_unique_blockers(removal_messages:, rows:, departure:, arrangement:)
    seen = {}
    unique = []

    removal_messages.each do |message|
      append_unique_blocker!(
        unique,
        seen,
        message: message,
        corrective_path: commitments_path(departure, arrangement),
        corrective_label: "Open commitments",
        editor_anchor: nil,
        kind: nil,
        definition_id: nil
      )
    end

    rows.each do |row|
      next if row.blocker.blank?

      path, label = corrective_for_row(row, departure, arrangement)
      append_unique_blocker!(
        unique,
        seen,
        message: row.blocker,
        corrective_path: path,
        corrective_label: label,
        editor_anchor: row.editor_anchor,
        kind: row.kind,
        definition_id: row.definition_id
      )
    end

    unique
  end

  def append_unique_blocker!(unique, seen, message:, corrective_path:, corrective_label:, editor_anchor:, kind:, definition_id:)
    key = normalize_blocker_message(message)
    return if key.blank? || seen[key]

    seen[key] = true
    unique << UniqueBlocker.new(
      message: message,
      corrective_path: corrective_path,
      corrective_label: corrective_label,
      editor_anchor: editor_anchor,
      kind: kind,
      definition_id: definition_id
    )
  end

  def normalize_blocker_message(message)
    message.to_s.strip.downcase.gsub(/\s+/, " ")
  end

  def corrective_for_row(row, departure, arrangement)
    if cabin_quantity_blocker?(row.blocker)
      path = cabin_inventory_corrective_path(row, departure, arrangement)
      return [ path, "Open cabin inventory" ]
    end

    case row.kind
    when "deposit"
      [
        deposits_and_deadlines_path(
          departure,
          arrangement,
          deposit_editor: "edit",
          deposit_id: row.definition_id
        ),
        "Edit deposit requirement"
      ]
    when "deadline"
      [
        deposits_and_deadlines_path(
          departure,
          arrangement,
          editor: "edit",
          deadline_id: row.definition_id
        ),
        "Edit Supplier deadline"
      ]
    else
      [ deposits_and_deadlines_path(departure, arrangement), "Open deposits and deadlines" ]
    end
  end

  def cabin_quantity_blocker?(message)
    message.to_s.match?(CABIN_QUANTITY_MESSAGE)
  end

  def cabin_inventory_corrective_path(row, departure, arrangement)
    resource_id = cabin_resource_id_for(row)
    if resource_id.present?
      return Rails.application.routes.url_helpers
        .edit_departure_arrangement_cruise_cabin_category_path(
          departure, arrangement, resource_id
        )
    end

    Rails.application.routes.url_helpers
      .departure_arrangement_cruise_path(departure, arrangement)
  end

  def cabin_resource_id_for(row)
    return unless row.kind == "deposit" && row.definition_id.present?

    definition = SupplierDepositRequirementDefinition.find_by(id: row.definition_id)
    return unless definition

    links = definition.supplier_deposit_requirement_definition_coverage_links.to_a
    resource_ids = links.filter_map(&:supplier_resource_id).uniq
    return resource_ids.first if resource_ids.size == 1

    pool_ids = links.filter_map(&:capacity_pool_id).uniq
    return if pool_ids.empty?

    pools = CapacityPool.where(id: pool_ids, agency_id: @agency.id)
    pool_resource_ids = pools.filter_map(&:supplier_resource_id).uniq
    pool_resource_ids.first if pool_resource_ids.size == 1
  end

  def due_sentence_for(provisional, time_zone)
    if provisional.calculated_on.present?
      "#{provisional.calculated_on.iso8601} (#{time_zone})"
    elsif provisional.calculated_at.present?
      "#{provisional.calculated_at.in_time_zone(time_zone).strftime('%Y-%m-%d %H:%M')} (#{time_zone})"
    end
  end

  def deadline_coverage_summary(definition, cruise_shape)
    links = definition.supplier_deadline_definition_coverage_links.order(:position, :id).to_a
    projected = CruiseDeadlineTemplateSupport.project_coverage_fields(links)
    case projected[:scope]
    when "arrangement"
      "Entire Cruise (#{cruise_shape.item_definition&.name || "Arrangement Item"})"
    when "resource"
      "Selected cabin category"
    when "capacity_pool"
      "Selected cabin Capacity Pool"
    else
      "Advanced coverage"
    end
  end

  def activation_path_for(departure, arrangement)
    Rails.application.routes.url_helpers
      .departure_arrangement_activation_path(departure, arrangement)
  end

  def deposits_and_deadlines_path(departure, arrangement, **query)
    Rails.application.routes.url_helpers
      .departure_arrangement_cruise_deposits_and_deadlines_path(departure, arrangement, **query)
  end

  def commitments_path(departure, arrangement)
    Rails.application.routes.url_helpers
      .departure_arrangement_commitments_path(departure, arrangement)
  end
end
