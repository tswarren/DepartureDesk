# frozen_string_literal: true

# Saves a provisional Cruise agreement, confirms it, or records an explicit correction.
# Confirmation has no document. Ordinary edits cannot change a confirmed value.
class RecordCruiseSupplierAgreement < AgencyCommand
  include ArrangementCommandSupport

  COMMAND_NAME = "record_cruise_supplier_agreement"
  INTENTS = %w[save_provisional confirm correct].freeze

  def initialize(
    agency:, actor:, arrangement:, intent:, version_lock_version:, idempotency_key:,
    group_creation_date: nil, group_reference: nil, contract_date: nil, note: nil,
    deposit_treatment: nil
  )
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @intent = intent.to_s
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
    @group_creation_date = group_creation_date
    @group_reference = group_reference
    @contract_date = contract_date
    @note = note
    @deposit_treatment = deposit_treatment
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Choose how to record the Cruise agreement.", code: :invalid) unless INTENTS.include?(@intent)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version = lock_departure_arrangement_version!(@arrangement)
      ensure_draft_graph!(arrangement, version)
      ensure_departure_accepts_new_planning!(departure)
      ensure_cruise!(arrangement, version)

      attributes = normalized_attributes
      payload = attributes.merge(
        supplier_arrangement_version_id: version.id,
        intent: @intent
      )
      if (replay = replay_matching_command!(payload))
        return replay
      end

      ensure_current_lock_version!(version, @version_lock_version)
      record = persist!(arrangement, version, attributes)
      bump_version!(version)
      audit!(
        agency: @agency,
        action: "supplier_arrangement.updated",
        subject: arrangement,
        actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "supplier_arrangement_version_id" => version.id,
          "changed_fields" => [ "cruise_agreement.#{@intent}" ],
          "cruise_agreement_confirmation_id" => record.id
        }
      )
      claim_command!(payload, record)
      Result.new(status: :created, record: record)
    end
  end

  private

  def ensure_cruise!(arrangement, version)
    shape = DetectCruiseArrangementShape.new(
      agency: @agency, arrangement: arrangement, version: version
    ).call
    return if shape.compatible?

    raise Error.new("Agreement confirmation belongs on a Cruise.", code: :invalid_state)
  end

  def normalized_attributes
    reference = @group_reference.to_s.strip.presence
    note = @note.to_s.strip.presence
    treatment = @deposit_treatment.to_s.strip.presence
    creation_date = parse_date(@group_creation_date, "Group creation date")
    contract_date = parse_date(@contract_date, "Contract date")
    raise Error.new("Enter the group creation date.", code: :invalid) if creation_date.blank?
    if @intent != "save_provisional"
      raise Error.new("Enter the group reference.", code: :invalid) if reference.blank?
      raise Error.new("Enter the contract date.", code: :invalid) if contract_date.blank?
    end
    if reference && reference.length > SupplierArrangementCruiseAgreementConfirmation::REFERENCE_LIMIT
      raise Error.new("Group reference is too long.", code: :invalid)
    end

    {
      group_creation_date: creation_date,
      group_reference: reference,
      contract_date: contract_date,
      note: note,
      deposit_treatment: treatment
    }
  end

  def parse_date(value, label)
    return nil if value.blank?
    return value if value.is_a?(Date)

    Date.iso8601(value.to_s)
  rescue ArgumentError
    raise Error.new("Enter a valid #{label.downcase}.", code: :invalid)
  end

  def persist!(arrangement, version, attributes)
    current = version.supplier_arrangement_cruise_agreement_confirmations.lock.find_by(current: true)
    case @intent
    when "save_provisional"
      save_provisional!(arrangement, version, current, attributes)
    when "confirm"
      confirm!(arrangement, version, current, attributes)
    when "correct"
      correct!(arrangement, version, current, attributes)
    end
  end

  def save_provisional!(arrangement, version, current, attributes)
    if current&.confirmed?
      raise Error.new(
        "Confirmed agreement values change only through an explicit correction.",
        code: :invalid_state
      )
    end

    if current
      current.update!(attributes)
      return current
    end

    create_row!(arrangement, version, attributes.merge(status: "provisional", current: true))
  end

  def confirm!(arrangement, version, current, attributes)
    if current&.confirmed?
      raise Error.new(
        "This agreement is already confirmed. Use a correction to change the group reference or contract date.",
        code: :invalid_state
      )
    end

    confirmed = attributes.merge(
      status: "confirmed",
      current: true,
      confirmed_at: Time.current,
      confirmed_by: @actor
    )
    if current
      current.update!(confirmed)
      return current
    end

    create_row!(arrangement, version, confirmed)
  end

  def correct!(arrangement, version, current, attributes)
    unless current&.confirmed?
      raise Error.new("Confirm the agreement before correcting it.", code: :invalid_state)
    end

    current.update!(current: false)
    create_row!(
      arrangement,
      version,
      attributes.merge(
        status: "confirmed",
        current: true,
        confirmed_at: Time.current,
        confirmed_by: @actor,
        corrects: current
      )
    )
  end

  def create_row!(arrangement, version, attributes)
    version.supplier_arrangement_cruise_agreement_confirmations.create!(
      attributes.merge(
        agency: @agency,
        departure: arrangement.departure,
        supplier_arrangement: arrangement
      )
    )
  end

  def replay_matching_command!(payload)
    key = normalize_idempotency_key(@idempotency_key)
    digest = payload_digest(payload)
    lock_idempotency_slot!(COMMAND_NAME, key)
    existing = AgencyCommandIdempotencyKey.where(
      agency: @agency, command_name: COMMAND_NAME, idempotency_key: key
    ).lock.first
    return nil unless existing
    unless existing.payload_digest == digest
      raise Error.new("That idempotency key was already used for different input.", code: :conflict)
    end

    Result.new(
      status: :replayed,
      record: SupplierArrangementCruiseAgreementConfirmation.find(existing.result_record_id)
    )
  end

  def claim_command!(payload, record)
    AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: COMMAND_NAME,
      idempotency_key: normalize_idempotency_key(@idempotency_key),
      payload_digest: payload_digest(payload),
      result_record_type: SupplierArrangementCruiseAgreementConfirmation.name,
      result_record_id: record.id
    )
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("That idempotency key was already used for different input.", code: :conflict)
  end
end
