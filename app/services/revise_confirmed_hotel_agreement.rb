# frozen_string_literal: true

class ReviseConfirmedHotelAgreement < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, reason:, idempotency_key:,
    arrangement_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @reason = reason
    @idempotency_key = idempotency_key
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure = lock_departure_for!(@arrangement.departure_id)
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.versions.lock.find_by(status: "draft")
      payload = {
        supplier_arrangement_id: arrangement.id,
        confirmed_version_id: version&.id,
        arrangement_lock_version: @arrangement_lock_version,
        version_lock_version: @version_lock_version,
        reason: @reason.to_s.strip
      }
      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: key,
        payload: payload,
        result_class: SupplierArrangementVersion
      ) do
        validate_revision!(departure, arrangement, version)
        ensure_current_lock_version!(arrangement, @arrangement_lock_version)
        ensure_current_lock_version!(version, @version_lock_version)
        reason = normalize_revision_reason(@reason)
        CopySupplierArrangementVersionGraph.lock!(version)
        abandoned_at = Time.current
        version.update!(status: "abandoned", abandoned_at: abandoned_at, abandoned_reason: reason)
        revised = arrangement.versions.create!(
          agency: @agency,
          departure: departure,
          version_number: arrangement.versions.maximum(:version_number).to_i + 1,
          copied_from: version
        )
        CopySupplierArrangementVersionGraph.copy!(from: version, to: revised)
        audit!(
          agency: @agency,
          action: "supplier_arrangement.confirmed_agreement_revised",
          subject: arrangement,
          actor: @actor,
          details: {
            "supplier_arrangement_id" => arrangement.id,
            "abandoned_version_id" => version.id,
            "supplier_arrangement_version_id" => revised.id,
            "version_number" => revised.version_number,
            "reason" => reason
          }
        )
        revised
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("A draft version already exists.", code: :conflict)
  end

  private

  def validate_revision!(departure, arrangement, version)
    lodging = version&.arrangement_item_definitions&.exists?(category: "lodging")
    confirmed = version && SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
    unless departure.active? && arrangement.draft? && arrangement.governing_version_id.nil? &&
        version&.draft? && lodging && confirmed &&
        arrangement.versions.where(status: "draft").count == 1
      raise Error.new(
        "Only a confirmed Hotel draft can be revised before the first activation.",
        code: :invalid_state
      )
    end
  end

  def normalize_revision_reason(value)
    reason = value.to_s.strip
    raise Error.new("Enter a reason.", code: :invalid) if reason.blank?
    if reason.length > SupplierArrangementVersion::ABANDONED_REASON_LIMIT
      raise Error.new(
        "Reason must be #{SupplierArrangementVersion::ABANDONED_REASON_LIMIT} characters or fewer.",
        code: :invalid
      )
    end

    reason
  end
end
