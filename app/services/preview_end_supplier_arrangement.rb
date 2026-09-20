# frozen_string_literal: true

class PreviewEndSupplierArrangement < AgencyCommand
  include ArrangementCommandSupport

  PREVIEW_TTL = 15.minutes
  Result = Data.define(:status, :record, :raw_token, :evaluation)

  def initialize(agency:, actor:, arrangement:, selected_cascade_keys: nil,
    ending_reason: nil, ending_reason_label: nil, ending_reason_note: nil,
    replacement_arrangement_id: nil, required_acknowledgments: [])
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @selected_cascade_keys = Array(selected_cascade_keys).map(&:to_s).uniq
    @ending_reason = ending_reason.to_s.presence
    @ending_reason_label = ending_reason_label.to_s.strip.presence
    @ending_reason_note = ending_reason_note.to_s.strip.presence
    @replacement_arrangement_id = replacement_arrangement_id
    @required_acknowledgments = Array(required_acknowledgments).map(&:to_s)
  end

  def call
    ensure_arrangement_actor!

    evaluation = EvaluateSupplierArrangementEnding.new(
      agency: @agency, arrangement: @arrangement
    ).call

    selected = resolve_selected_keys(evaluation)
    validate_reason!(evaluation)

    payload = serialize_payload(evaluation, selected)
    digest = digest_for(
      evaluation:,
      selected_keys: selected,
      ending_reason: @ending_reason,
      ending_reason_label: @ending_reason_label,
      ending_reason_note: @ending_reason_note,
      replacement_arrangement_id: @replacement_arrangement_id,
      required_acknowledgments: @required_acknowledgments
    )
    raw_token = SecureRandom.hex(32)

    preview = SupplierArrangementEndingPreview.create!(
      agency_id: evaluation.arrangement.agency_id,
      departure_id: evaluation.arrangement.departure_id,
      supplier_arrangement_id: evaluation.arrangement.id,
      supplier_arrangement_version_id: evaluation.version.id,
      arrangement_lock_version: evaluation.arrangement.lock_version,
      version_lock_version: evaluation.version.lock_version,
      actor_id: @actor.id,
      payload:,
      digest_sha256: digest,
      token_digest: Digest::SHA256.hexdigest(raw_token),
      expires_at: Time.current + PREVIEW_TTL,
      ending_reason: @ending_reason,
      ending_reason_label: @ending_reason_label,
      ending_reason_note: @ending_reason_note,
      replacement_arrangement_id: @replacement_arrangement_id,
      selected_cascade_keys: selected,
      required_acknowledgments: @required_acknowledgments
    )

    Result.new(status: :created, record: preview, raw_token:, evaluation:)
  end

  def self.find_valid_preview!(agency:, arrangement:, raw_token:, at: Time.current)
    preview = SupplierArrangementEndingPreview
      .where(agency_id: agency.id, supplier_arrangement_id: arrangement.id)
      .order(created_at: :desc)
      .detect { |row| row.matches_token?(raw_token) }
    raise Error.new("Ending preview is missing or invalid.", code: :invalid) if preview.nil?
    if preview.expired?(at:)
      raise Error.new("Ending preview expired. Refresh the preview and try again.", code: :conflict)
    end

    preview
  end

  private

  def resolve_selected_keys(evaluation)
    required = evaluation.cascades.select(&:required).map(&:key)
    eligible = evaluation.cascades.map(&:key)
    requested = @selected_cascade_keys.presence || required
    unknown = requested - eligible
    if unknown.any?
      raise Error.new("Selected ending cascade is not eligible.", code: :invalid)
    end

    (requested | required).uniq
  end

  def validate_reason!(evaluation)
    return if @ending_reason.blank?

    unless EvaluateSupplierArrangementEnding::ENDING_REASONS.include?(@ending_reason)
      raise Error.new("Choose a valid ending reason.", code: :invalid)
    end
    if @ending_reason == "other" && (@ending_reason_label.blank? || @ending_reason_note.blank?)
      raise Error.new("Other ending reason requires a label and note.", code: :invalid)
    end
    if @ending_reason == "replaced"
      replacement = @agency.supplier_arrangements.find_by(id: @replacement_arrangement_id)
      if replacement.nil? || replacement.departure_id != evaluation.arrangement.departure_id
        raise Error.new("Replacement Arrangement must belong to this Departure.", code: :invalid)
      end
      if replacement.id == evaluation.arrangement.id
        raise Error.new("Replacement Arrangement must be a different Arrangement.", code: :invalid)
      end
    end
  end

  def serialize_payload(evaluation, selected)
    {
      "blockers" => evaluation.blockers.map { |row|
        {
          "code" => row.code,
          "message" => row.message,
          "resolution_path" => row.resolution_path,
          "target_ids" => row.target_ids
        }
      },
      "cascades" => evaluation.cascades.map { |row|
        {
          "key" => row.key,
          "kind" => row.kind,
          "required" => row.required,
          "selectable" => row.selectable,
          "label" => row.label,
          "target_id" => row.target_id,
          "target_type" => row.target_type,
          "notes" => row.notes,
          "selected" => selected.include?(row.key)
        }
      },
      "required_informational_supersessions" => evaluation.required_informational_supersessions,
      "source_versions" => evaluation.source_versions,
      "reason_choices" => evaluation.reason_choices,
      "selected_cascade_keys" => selected,
      "ending_reason" => @ending_reason,
      "replacement_arrangement_id" => @replacement_arrangement_id,
      "required_acknowledgments" => @required_acknowledgments
    }
  end

  def digest_for(evaluation:, selected_keys:, ending_reason:, ending_reason_label:,
    ending_reason_note:, replacement_arrangement_id:, required_acknowledgments:)
    canonical = {
      arrangement_id: evaluation.arrangement.id,
      version_id: evaluation.version.id,
      arrangement_lock_version: evaluation.arrangement.lock_version,
      version_lock_version: evaluation.version.lock_version,
      blocker_codes: evaluation.blockers.map(&:code).sort,
      eligible_keys: evaluation.cascades.map(&:key).sort,
      selected_keys: selected_keys.sort,
      source_versions: evaluation.source_versions,
      ending_reason:,
      ending_reason_label:,
      ending_reason_note:,
      replacement_arrangement_id:,
      required_acknowledgments: required_acknowledgments.sort
    }
    Digest::SHA256.hexdigest(JSON.generate(deep_sort(canonical)))
  end

  def deep_sort(value)
    case value
    when Hash
      value.keys.sort_by(&:to_s).to_h { |key| [ key.to_s, deep_sort(value[key]) ] }
    when Array
      value.map { |entry| deep_sort(entry) }
    else
      value
    end
  end
end
