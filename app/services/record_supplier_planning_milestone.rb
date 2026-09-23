# frozen_string_literal: true

# Records a Staff planning milestone. For already-materialized earlier_of deposits,
# replaces an unelapsed governing Deadline at the milestone time without opening a
# duplicate deposit commitment.
class RecordSupplierPlanningMilestone < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, version:, kind:, occurred_on: nil,
    occurred_at: nil, note: nil, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @kind = kind.to_s
    @occurred_on = occurred_on
    @occurred_at = occurred_at
    @note = note.to_s.strip.presence
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    unless SupplierPlanningMilestoneOccurrence::KINDS.include?(@kind)
      raise Error.new("Choose a supported planning milestone kind.", code: :invalid)
    end

    date, instant = normalize_occurrence_precision!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement_row = @agency.supplier_arrangements.find(@arrangement.id)
      lock_suppliers_in_uuid_order!(arrangement_row.contracting_supplier_id)
      departure = lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      version = arrangement.versions.lock.find(@version.id)
      unless version.activated? || version.superseded?
        raise Error.new(
          "Planning milestones require an activated Arrangement version.", code: :invalid_state
        )
      end

      payload = {
        kind: @kind,
        supplier_arrangement_version_id: version.id,
        occurred_on: date&.iso8601,
        occurred_at: instant&.utc&.iso8601(6),
        note: @note
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierPlanningMilestoneOccurrence
      ) do
        now = Time.current
        milestone = SupplierPlanningMilestoneOccurrence.create!(
          agency: @agency,
          departure:,
          supplier_arrangement: arrangement,
          supplier_arrangement_version: version,
          kind: @kind,
          occurred_on: date,
          occurred_at: instant,
          note: @note,
          actor: @actor,
          recorded_at: now
        )
        replace_unelapsed_deposit_deadlines!(arrangement, version, milestone, at: now)
        ReevaluateQuantityDerivedDepositCumulativeAlreadyLocked.new(
          agency: @agency, actor: @actor, arrangement:, version:, at: now
        ).call
        rebuild_exposure_projection_already_locked!(arrangement, version:, at: now)
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.planning_milestone_recorded",
          details: {
            "supplier_planning_milestone_occurrence_id" => milestone.id,
            "kind" => milestone.kind,
            "occurred_on" => milestone.occurred_on&.iso8601,
            "occurred_at" => milestone.occurred_at&.utc&.iso8601(6)
          }
        )
        milestone
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  rescue SupplierDeadlineRuleEvaluator::UnsupportedRule => error
    raise Error.new(error.message, code: :invalid)
  end

  private

  def normalize_occurrence_precision!
    if @occurred_on.present? && @occurred_at.present?
      raise Error.new("Record either a milestone date or timestamp, not both.", code: :invalid)
    end
    if @occurred_on.blank? && @occurred_at.blank?
      raise Error.new("Enter the milestone date or timestamp.", code: :invalid)
    end

    date = @occurred_on.present? ? Date.iso8601(@occurred_on.to_s) : nil
    instant =
      if @occurred_at.blank?
        nil
      elsif @occurred_at.is_a?(Time) || @occurred_at.is_a?(ActiveSupport::TimeWithZone)
        @occurred_at
      else
        Time.zone.parse(@occurred_at.to_s)
      end
    raise Error.new("Enter a valid milestone timestamp.", code: :invalid) if @occurred_at.present? && instant.blank?

    [ date, instant ]
  rescue ArgumentError, TypeError
    raise Error.new("Enter a valid milestone date or timestamp.", code: :invalid)
  end

  def replace_unelapsed_deposit_deadlines!(arrangement, version, milestone, at:)
    tranches = version.supplier_deposit_requirement_tranches
      .includes(:supplier_deposit_requirement_definition, :governing_deadline_occurrence)
      .order(:materialized_at, :id)
      .lock

    commitments_before = arrangement.supplier_commitments.where(opening_kind: "deposit_requirement").count

    tranches.each do |tranche|
      definition = tranche.supplier_deposit_requirement_definition
      next unless definition.rule_shape.in?(%w[earlier_of later_of])
      next unless milestone_arm?(definition)

      governing = tranche.governing_deadline_occurrence
      next if governing.nil? || governing.superseded_at.present?
      next if governing.elapsed?(at:)

      evaluated = SupplierDeadlineRuleEvaluator.call(
        definition:,
        departure: arrangement.departure,
        at:,
        allow_milestones: true,
        unresolved_milestone_policy: :reject,
        milestone_occurrences: [ milestone ]
      )
      replacement = SupplierDeadlineOccurrence.create!(
        agency_id: tranche.agency_id,
        departure_id: tranche.departure_id,
        supplier_arrangement_id: tranche.supplier_arrangement_id,
        supplier_arrangement_version_id: tranche.supplier_arrangement_version_id,
        supplier_deadline_definition: nil,
        supplier_deposit_requirement_definition: definition,
        supplier_arrangement_activation: tranche.supplier_arrangement_activation,
        deadline_type: "deposit_due",
        kind: "actionable",
        rule_shape: definition.rule_shape,
        rule_parameters_snapshot: definition.rule_parameters,
        rule_inputs_snapshot: evaluated[:rule_inputs_snapshot],
        precision: definition.precision,
        time_zone: definition.time_zone,
        cardinality: "one_shared",
        coverage_snapshot: tranche.coverage_snapshot,
        calculated_on: evaluated[:calculated_on],
        calculated_at: evaluated[:calculated_at],
        materialization_key: "deposit_definition:#{definition.id}:milestone:#{milestone.id}",
        predecessor_occurrence: governing,
        actor: @actor,
        materialized_at: at
      )
      governing.mark_superseded!(at:)
      RefreshSupplierDeadlineProjection.call(occurrence: replacement, at:)
      tranche.replace_governing_deadline!(occurrence: replacement)
    end

    commitments_after = arrangement.supplier_commitments.where(opening_kind: "deposit_requirement").count
    return if commitments_after == commitments_before

    raise Error.new("Planning milestone must not open a duplicate deposit commitment.", code: :invalid_state)
  end

  def milestone_arm?(definition)
    arms = Array(definition.rule_parameters["arms"] || definition.rule_parameters[:arms])
    arms.any? do |arm|
      arm = arm.with_indifferent_access
      arm[:rule_shape].to_s == SupplierDeadlineRuleEvaluator::MILESTONE_SHAPE &&
        arm.dig(:rule_parameters, :kind).to_s == @kind
    end
  end
end
