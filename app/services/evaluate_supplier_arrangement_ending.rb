# frozen_string_literal: true

# Evaluates live governing state for Arrangement ending preview (M3E.6a).
# Does not mutate Arrangement lifecycle.
class EvaluateSupplierArrangementEnding
  ENDING_REASONS = %w[
    planning_concluded
    agreement_expired
    not_proceeding_no_live_commitment
    replaced
    duplicate_or_entered_in_error
    other
  ].freeze

  CASCADE_KINDS = %w[
    cancel_open_commitment
    withdraw_future_capacity
    apply_authorized_capacity_release
    abandon_draft_successor
    cancel_actionable_deadline_with_commitment
    supersede_future_informational_deadline
  ].freeze

  Blocker = Data.define(:code, :message, :resolution_path, :target_ids)
  CascadeCandidate = Data.define(
    :key, :kind, :required, :selectable, :label, :target_id, :target_type, :notes
  )
  Evaluation = Data.define(
    :arrangement, :version, :blockers, :cascades, :required_informational_supersessions,
    :source_versions, :reason_choices
  )

  def initialize(agency:, arrangement:, at: Time.current, selected_cascade_keys: nil)
    @agency = agency
    @arrangement = arrangement
    @at = at
    @selected_cascade_keys = selected_cascade_keys
  end

  def call
    arrangement = @agency.supplier_arrangements.find(@arrangement.id)
    unless arrangement.active?
      raise AgencyCommand::Error.new(
        "Only an active Supplier Arrangement can be previewed for ending.",
        code: :invalid_state
      )
    end

    version = arrangement.governing_version
    raise AgencyCommand::Error.new("Governing version is required.", code: :invalid_state) if version.nil?

    catch_up_due_projections!(version)

    open_commitments = open_commitments_for(arrangement)
    cascades = []
    cascades.concat(commitment_cancel_candidates(open_commitments))
    cascades.concat(capacity_withdraw_candidates(arrangement))
    cascades.concat(capacity_release_candidates(arrangement))
    cascades.concat(successor_abandon_candidates(arrangement))
    cascades.concat(actionable_deadline_with_commitment_candidates(arrangement, open_commitments))
    cascades.concat(informational_deadline_supersession_candidates(arrangement, version))

    required = cascades.select(&:required).map(&:key)
    selected_keys = if @selected_cascade_keys.nil?
      required
    else
      (Array(@selected_cascade_keys).map(&:to_s) | required).uniq
    end
    blockers = build_blockers(
      arrangement:, version:, open_commitments:, cascades:, selected_keys:
    )

    Evaluation.new(
      arrangement:,
      version:,
      blockers:,
      cascades:,
      required_informational_supersessions: cascades.select { |row|
        row.kind == "supersede_future_informational_deadline"
      }.map(&:key),
      source_versions: {
        "arrangement_lock_version" => arrangement.lock_version,
        "version_lock_version" => version.lock_version,
        "governing_version_id" => version.id
      },
      reason_choices: ENDING_REASONS
    )
  end

  private

  def catch_up_due_projections!(version)
    SupplierDeadlineOccurrence
      .where(agency_id: @agency.id, supplier_arrangement_version_id: version.id, superseded_at: nil)
      .find_each do |occurrence|
        RefreshSupplierDeadlineProjection.call(occurrence:, at: @at)
      end
  end

  def open_commitments_for(arrangement)
    SupplierCommitment
      .where(agency_id: @agency.id, supplier_arrangement_id: arrangement.id)
      .includes(:supplier_commitment_dispositions)
      .order(:id)
      .select(&:open_state?)
  end

  def commitment_cancel_candidates(open_commitments)
    open_commitments.map do |commitment|
      CascadeCandidate.new(
        key: "cancel_open_commitment:#{commitment.id}",
        kind: "cancel_open_commitment",
        required: false,
        selectable: true,
        label: "Cancel open commitment",
        target_id: commitment.id,
        target_type: "SupplierCommitment",
        notes: commitment.opening_kind
      )
    end
  end

  def capacity_withdraw_candidates(arrangement)
    CapacityProjection
      .where(agency_id: @agency.id, supplier_arrangement_id: arrangement.id)
      .where("current_supplier_capacity > 0")
      .order(:id)
      .map do |projection|
        CascadeCandidate.new(
          key: "withdraw_future_capacity:#{projection.capacity_pool_id}",
          kind: "withdraw_future_capacity",
          required: false,
          selectable: true,
          label: "Withdraw remaining Pool capacity",
          target_id: projection.capacity_pool_id,
          target_type: "CapacityPool",
          notes: "remaining=#{projection.current_supplier_capacity}"
        )
      end
      .uniq(&:key)
  end

  def capacity_release_candidates(_arrangement)
    # Eligible only when a previously authorized release path exists; none are auto-detected
    # without an explicit authorized release record in M3E.6a.
    []
  end

  def successor_abandon_candidates(arrangement)
    draft = arrangement.versions.find_by(status: "draft")
    return [] if draft.nil?
    return [] unless draft.copied_from_id == arrangement.governing_version_id

    [
      CascadeCandidate.new(
        key: "abandon_draft_successor:#{draft.id}",
        kind: "abandon_draft_successor",
        required: false,
        selectable: true,
        label: "Abandon unactivated draft successor",
        target_id: draft.id,
        target_type: "SupplierArrangementVersion",
        notes: nil
      )
    ]
  end

  def actionable_deadline_with_commitment_candidates(arrangement, open_commitments)
    open_ids = open_commitments.map(&:id)
    SupplierDeadlineOccurrence
      .where(
        agency_id: @agency.id,
        supplier_arrangement_id: arrangement.id,
        kind: "actionable",
        superseded_at: nil
      )
      .includes(:supplier_commitments)
      .order(:id)
      .filter_map do |occurrence|
        next if occurrence.elapsed?(at: @at)

        governed = occurrence.supplier_commitments.select { |row| open_ids.include?(row.id) }
        next if governed.blank?

        CascadeCandidate.new(
          key: "cancel_actionable_deadline_with_commitment:#{occurrence.id}",
          kind: "cancel_actionable_deadline_with_commitment",
          required: false,
          selectable: true,
          label: "Cancel unelapsed actionable Deadline with its open commitment",
          target_id: occurrence.id,
          target_type: "SupplierDeadlineOccurrence",
          notes: governed.map(&:id).join(",")
        )
      end
  end

  def informational_deadline_supersession_candidates(arrangement, _version)
    SupplierDeadlineOccurrence
      .where(
        agency_id: @agency.id,
        supplier_arrangement_id: arrangement.id,
        kind: "informational",
        superseded_at: nil
      )
      .order(:id)
      .filter_map do |occurrence|
        next if occurrence.elapsed?(at: @at)

        CascadeCandidate.new(
          key: "supersede_future_informational_deadline:#{occurrence.id}",
          kind: "supersede_future_informational_deadline",
          required: true,
          selectable: false,
          label: "Supersede future informational Deadline",
          target_id: occurrence.id,
          target_type: "SupplierDeadlineOccurrence",
          notes: "ending provenance"
        )
      end
  end

  def build_blockers(arrangement:, version:, open_commitments:, cascades:, selected_keys:)
    blockers = []
    selected = cascades.select { |row| selected_keys.include?(row.key) }
    selected_commitment_ids = selected.select { |row|
      row.kind == "cancel_open_commitment"
    }.map(&:target_id)
    selected_deadline_commitment_ids = selected.select { |row|
      row.kind == "cancel_actionable_deadline_with_commitment"
    }.flat_map { |row| row.notes.to_s.split(",") }.reject(&:blank?)

    covered = (selected_commitment_ids + selected_deadline_commitment_ids).uniq
    uncovered = open_commitments.reject { |row| covered.include?(row.id) }
    if uncovered.any?
      blockers << Blocker.new(
        code: "open_commitments",
        message: "Open commitments remain that are not selected for a permitted cascade.",
        resolution_path: "Select cancel cascades for each open commitment, or resolve them outside ending.",
        target_ids: uncovered.map(&:id)
      )
    end

    pending_reservations = pending_reservation_ids(arrangement)
    if pending_reservations.any?
      blockers << Blocker.new(
        code: "pending_reservation_activity",
        message: "Pending or unresolved Supplier Reservation activity requires its own workflow.",
        resolution_path: "Complete, withdraw, or cancel Reservation activity before ending.",
        target_ids: pending_reservations
      )
    end

    remaining_pools = cascades.select { |row|
      row.kind == "withdraw_future_capacity" && selected_keys.exclude?(row.key)
    }
    if remaining_pools.any?
      blockers << Blocker.new(
        code: "remaining_future_capacity",
        message: "Remaining future capacity requires explicit withdrawal or release.",
        resolution_path: "Select withdraw/release cascades for each remaining Pool.",
        target_ids: remaining_pools.map(&:target_id)
      )
    end

    governing_deadlines = unelapsed_actionable_governing_deadlines(arrangement, open_commitments)
    uncovered_deadlines = governing_deadlines.reject { |occurrence|
      selected_keys.include?("cancel_actionable_deadline_with_commitment:#{occurrence.id}")
    }
    if uncovered_deadlines.any?
      blockers << Blocker.new(
        code: "unelapsed_actionable_deadlines",
        message: "Unelapsed actionable Deadlines still govern open work.",
        resolution_path: "Select the Deadline-with-commitment cascade, or resolve the governed commitment first.",
        target_ids: uncovered_deadlines.map(&:id)
      )
    end

    if future_governing_exposure?(arrangement) && uncovered.any?
      blockers << Blocker.new(
        code: "future_governing_exposure",
        message: "Future guaranteed or contingent exposure would remain governing.",
        resolution_path: "Cover open commitments with ending cascades, or resolve exposure-driving work first.",
        target_ids: []
      )
    end

    if cascades.any? { |row|
         row.kind == "abandon_draft_successor" && selected_keys.exclude?(row.key)
       }
      blockers << Blocker.new(
        code: "unabandoned_draft_successor",
        message: "An un-abandoned draft successor remains.",
        resolution_path: "Select abandon draft successor, or abandon it outside ending.",
        target_ids: cascades.select { |row| row.kind == "abandon_draft_successor" }.map(&:target_id)
      )
    end

    blockers
  end

  def pending_reservation_ids(arrangement)
    SupplierReservationProjection
      .where(agency_id: @agency.id, supplier_arrangement_id: arrangement.id)
      .where(state: %w[requested partially_confirmed])
      .order(:id)
      .pluck(:supplier_reservation_id)
  end

  def unelapsed_actionable_governing_deadlines(arrangement, open_commitments)
    open_ids = open_commitments.map(&:id)
    SupplierDeadlineOccurrence
      .where(
        agency_id: @agency.id,
        supplier_arrangement_id: arrangement.id,
        kind: "actionable",
        superseded_at: nil
      )
      .order(:id)
      .select do |occurrence|
        next false if occurrence.elapsed?(at: @at)

        SupplierCommitment.where(
          supplier_deadline_occurrence_id: occurrence.id, id: open_ids
        ).exists?
      end
  end

  def future_governing_exposure?(arrangement)
    SupplierExposureSummary
      .where(agency_id: @agency.id, supplier_arrangement_id: arrangement.id)
      .where(qualification_band: %w[guaranteed contingent])
      .where("COALESCE(gross_minor_units, 0) > 0 OR COALESCE(required_deposit_minor_units, 0) > 0")
      .exists?
  end
end
