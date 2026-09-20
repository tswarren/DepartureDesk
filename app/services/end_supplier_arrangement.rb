# frozen_string_literal: true

class EndSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, preview_token:, idempotency_key:,
    selected_cascade_keys: nil, ending_reason: nil, ending_reason_label: nil,
    ending_reason_note: nil, replacement_arrangement_id: nil,
    required_acknowledgments: [], arrangement_lock_version: nil, version_lock_version: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @preview_token = preview_token
    @idempotency_key = idempotency_key
    @selected_cascade_keys = selected_cascade_keys
    @ending_reason = ending_reason
    @ending_reason_label = ending_reason_label
    @ending_reason_note = ending_reason_note
    @replacement_arrangement_id = replacement_arrangement_id
    @required_acknowledgments = required_acknowledgments
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement_row = @agency.supplier_arrangements.find(@arrangement.id)
      lock_suppliers_in_uuid_order!(arrangement_row.contracting_supplier_id)
      lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)

      version = arrangement.governing_version_id &&
        arrangement.versions.lock.find(arrangement.governing_version_id)
      if version.nil? && !arrangement.ended?
        raise Error.new("Governing version is required.", code: :invalid_state)
      end
      ensure_current_lock_version!(arrangement, @arrangement_lock_version) if @arrangement_lock_version
      ensure_current_lock_version!(version, @version_lock_version) if @version_lock_version && version

      payload = {
        supplier_arrangement_id: arrangement.id,
        preview_token_digest: Digest::SHA256.hexdigest(@preview_token.to_s),
        selected_cascade_keys: Array(@selected_cascade_keys).map(&:to_s).sort,
        ending_reason: @ending_reason.to_s,
        ending_reason_label: @ending_reason_label.to_s,
        ending_reason_note: @ending_reason_note.to_s,
        replacement_arrangement_id: @replacement_arrangement_id.to_s,
        required_acknowledgments: Array(@required_acknowledgments).map(&:to_s).sort
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierArrangementEnding
      ) do
        raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
        raise Error.new("Only an active Supplier Arrangement can end.", code: :invalid_state) unless arrangement.active?
        version = arrangement.versions.lock.find(arrangement.governing_version_id)
        preview = find_preview!(arrangement)
        selected_seed = Array(@selected_cascade_keys).presence || preview.selected_cascade_keys
        evaluation = EvaluateSupplierArrangementEnding.new(
          agency: @agency, arrangement:, selected_cascade_keys: selected_seed
        ).call
        selected = resolve_selected!(preview, evaluation)
        validate_reason!(evaluation, preview)
        validate_live_digest!(preview, evaluation, selected)

        if evaluation.blockers.any?
          raise Error.new(evaluation.blockers.first.message, code: :invalid_state)
        end

        cascade_manifest = execute_cascades!(arrangement, version, selected, evaluation)

        re_evaluation = EvaluateSupplierArrangementEnding.new(
          agency: @agency, arrangement:, selected_cascade_keys: selected
        ).call
        if re_evaluation.blockers.any?
          raise Error.new(re_evaluation.blockers.first.message, code: :invalid_state)
        end

        ended_at = Time.current
        ending = SupplierArrangementEnding.create!(
          agency_id: arrangement.agency_id,
          departure_id: arrangement.departure_id,
          supplier_arrangement_id: arrangement.id,
          supplier_arrangement_version_id: version.id,
          supplier_arrangement_ending_preview_id: preview.id,
          ending_reason: effective_reason(preview),
          ending_reason_label: effective_label(preview),
          ending_reason_note: effective_note(preview),
          replacement_arrangement_id: effective_replacement_id(preview),
          selected_cascade_keys: selected,
          cascade_manifest:,
          preview_digest_sha256: preview.digest_sha256,
          actor_id: @actor.id,
          ended_at:
        )
        arrangement.update!(status: "ended", ended_at:)
        RebuildSupplierExposureProjectionAlreadyLocked.new(
          agency: @agency, arrangement:, version:
        ).call
        RebuildSupplierAttentionProjectionAlreadyLocked.new(
          agency: @agency, arrangement:, version:
        ).call

        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.ended",
          details: {
            "supplier_arrangement_ending_id" => ending.id,
            "ending_reason" => ending.ending_reason,
            "selected_cascade_keys" => selected,
            "supplier_arrangement_ending_preview_id" => preview.id
          }
        )
        ending
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  end

  private

  def find_preview!(arrangement)
    preview = SupplierArrangementEndingPreview
      .where(agency_id: @agency.id, supplier_arrangement_id: arrangement.id)
      .order(created_at: :desc)
      .detect { |row| row.matches_token?(@preview_token) }
    raise Error.new("Ending preview is missing or invalid.", code: :invalid) if preview.nil?

    preview
  end

  def resolve_selected!(preview, evaluation)
    if evaluation.cascades.map(&:key).sort != Array(preview.payload["cascades"]).map { |row| row["key"] }.sort
      raise Error.new(
        "Ending candidates changed. Refresh the preview and try again.",
        code: :conflict
      )
    end

    requested = Array(@selected_cascade_keys).presence || preview.selected_cascade_keys
    requested = Array(requested).map(&:to_s).uniq
    required = evaluation.cascades.select(&:required).map(&:key)
    eligible = evaluation.cascades.map(&:key)
    unknown = requested - eligible
    raise Error.new("Selected ending cascade is not eligible.", code: :invalid) if unknown.any?

    (requested | required).uniq
  end

  def validate_reason!(evaluation, preview)
    reason = effective_reason(preview)
    raise Error.new("Choose a valid ending reason.", code: :invalid) if reason.blank?
    unless EvaluateSupplierArrangementEnding::ENDING_REASONS.include?(reason)
      raise Error.new("Choose a valid ending reason.", code: :invalid)
    end
    if reason == "other" && (effective_label(preview).blank? || effective_note(preview).blank?)
      raise Error.new("Other ending reason requires a label and note.", code: :invalid)
    end
    return unless reason == "replaced"

    replacement = @agency.supplier_arrangements.find_by(id: effective_replacement_id(preview))
    if replacement.nil? || replacement.departure_id != evaluation.arrangement.departure_id ||
        replacement.id == evaluation.arrangement.id
      raise Error.new("Replacement Arrangement must belong to this Departure.", code: :invalid)
    end
  end

  def validate_live_digest!(preview, evaluation, selected)
    acknowledgments = Array(@required_acknowledgments).presence || preview.required_acknowledgments
    digest = PreviewEndSupplierArrangement.digest_for(
      evaluation:,
      selected_keys: selected,
      ending_reason: effective_reason(preview),
      ending_reason_label: effective_label(preview),
      ending_reason_note: effective_note(preview),
      replacement_arrangement_id: effective_replacement_id(preview),
      required_acknowledgments: acknowledgments
    )
    unless ActiveSupport::SecurityUtils.secure_compare(digest, preview.digest_sha256)
      raise Error.new(
        "Ending preview no longer matches live governing state. Refresh the preview.",
        code: :conflict
      )
    end
    return unless preview.expired?

    raise Error.new("Ending preview expired. Refresh the preview and try again.", code: :conflict)
  end

  def blockers_for(arrangement, cascades, selected)
    open_commitments = SupplierCommitment.where(supplier_arrangement: arrangement).select(&:open_state?)
    EvaluateSupplierArrangementEnding.new(agency: @agency, arrangement:).send(
      :build_blockers,
      arrangement:,
      version: arrangement.governing_version,
      open_commitments:,
      cascades:,
      selected_keys: selected
    )
  end

  def execute_cascades!(arrangement, version, selected, evaluation)
    manifest = { "executed" => [] }
    selected.each do |key|
      candidate = evaluation.cascades.find { |row| row.key == key }
      next if candidate.nil?

      case candidate.kind
      when "cancel_open_commitment"
        cancel_commitment!(arrangement, version, candidate.target_id)
      when "withdraw_future_capacity"
        withdraw_pool_already_locked!(arrangement, candidate.target_id)
      when "abandon_draft_successor"
        abandon_successor_already_locked!(arrangement, candidate.target_id)
      when "cancel_actionable_deadline_with_commitment"
        cancel_deadline_with_commitments!(arrangement, version, candidate)
      when "supersede_future_informational_deadline"
        supersede_occurrence!(candidate.target_id)
      when "apply_authorized_capacity_release"
        raise Error.new("Authorized capacity release cascade is not available.", code: :invalid)
      else
        raise Error.new("Unknown ending cascade.", code: :invalid)
      end
      manifest["executed"] << key
    end
    manifest
  end

  def cancel_commitment!(arrangement, version, commitment_id)
    commitment = arrangement.supplier_commitments.lock.find(commitment_id)
    return unless commitment.open_state?

    SupplierCommitmentDisposition.create!(
      agency_id: arrangement.agency_id,
      departure_id: arrangement.departure_id,
      supplier_arrangement_id: arrangement.id,
      supplier_arrangement_version_id: version.id,
      supplier_commitment_id: commitment.id,
      outcome: "cancelled",
      reason: "Arrangement ending",
      actor_id: @actor.id,
      occurred_at: Time.current,
      recorded_at: Time.current,
      accepted_risk_acknowledged: false
    )
  end

  def cancel_deadline_with_commitments!(arrangement, version, candidate)
    occurrence = SupplierDeadlineOccurrence.lock.find_by!(
      id: candidate.target_id, agency_id: @agency.id, supplier_arrangement_id: arrangement.id
    )
    candidate.notes.to_s.split(",").reject(&:blank?).each do |commitment_id|
      cancel_commitment!(arrangement, version, commitment_id)
    end
    supersede_occurrence!(occurrence.id)
  end

  def supersede_occurrence!(occurrence_id)
    occurrence = SupplierDeadlineOccurrence.lock.find_by!(id: occurrence_id, agency_id: @agency.id)
    return if occurrence.superseded_at.present?

    occurrence.mark_superseded!(at: Time.current)
  end

  def withdraw_pool_already_locked!(arrangement, pool_id)
    projection = CapacityProjection.lock.find_by(
      agency_id: @agency.id, capacity_pool_id: pool_id, supplier_arrangement_id: arrangement.id
    )
    return if projection.nil? || projection.current_supplier_capacity <= 0

    # Ending cascade records a withdrawn event through the public command while holding
    # Arrangement lock; nested command re-locks in compatible order.
    WithdrawCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: arrangement.capacity_pools.find(pool_id),
      quantity: projection.current_supplier_capacity,
      projection_lock_version: projection.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { note: "Arrangement ending withdrawal" },
      effective_on: Date.current
    ).call
  end

  def abandon_successor_already_locked!(arrangement, version_id)
    version = arrangement.versions.lock.find(version_id)
    raise Error.new("Successor is not an abandonable draft.", code: :invalid_state) unless version.draft?

    version.update!(
      status: "abandoned",
      abandoned_at: Time.current,
      abandoned_reason: "Abandoned during Arrangement ending"
    )
  end

  def effective_reason(preview)
    @ending_reason.presence || preview.ending_reason
  end

  def effective_label(preview)
    @ending_reason_label.presence || preview.ending_reason_label
  end

  def effective_note(preview)
    @ending_reason_note.presence || preview.ending_reason_note
  end

  def effective_replacement_id(preview)
    @replacement_arrangement_id.presence || preview.replacement_arrangement_id
  end
end
