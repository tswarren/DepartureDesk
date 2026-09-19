# frozen_string_literal: true

# Closes an open deposit_requirement commitment with Staff attestation
# "Confirmed handled outside DepartureDesk". Uses disposition outcome handled_externally
# (note required, no confirmation evidence, accepted_risk false) rather than satisfied+evidence,
# because deposit attestation is not supplier confirmation coverage and must never be labeled paid.
class AttestSupplierDepositHandledExternally < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, commitment:, note:, confirmed_complete:,
    idempotency_key:, occurred_at: nil)
    @agency = agency
    @actor = actor
    @commitment = commitment
    @note = note.to_s.strip
    @confirmed_complete = ActiveModel::Type::Boolean.new.cast(confirmed_complete)
    @idempotency_key = idempotency_key
    @occurred_at = occurred_at
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Enter an attestation note.", code: :invalid) if @note.blank?
    unless @confirmed_complete
      raise Error.new(
        "Confirm the complete current deposit amount was handled outside DepartureDesk.",
        code: :invalid
      )
    end

    occurred = normalize_optional_occurred_at(@occurred_at)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!

      commitment_row = SupplierCommitment.find_by!(id: @commitment.id, agency_id: @agency.id)
      unless commitment_row.deposit_requirement?
        raise Error.new("Only deposit requirement commitments can be attested externally.", code: :invalid)
      end

      arrangement_row = @agency.supplier_arrangements.find(commitment_row.supplier_arrangement_id)
      lock_suppliers_in_uuid_order!(commitment_row.committed_supplier_id)
      lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      commitment = arrangement.supplier_commitments.lock.find(commitment_row.id)
      tranche = commitment.supplier_deposit_requirement_tranche.lock!
      unless commitment.open_state?
        raise Error.new("That deposit commitment is no longer open.", code: :invalid_state)
      end

      payload = {
        outcome: "handled_externally",
        supplier_commitment_id: commitment.id,
        supplier_deposit_requirement_tranche_id: tranche.id,
        attested_amount_minor_units: tranche.current_amount_minor_units,
        currency: tranche.currency,
        note: @note,
        occurred_at: occurred&.utc&.iso8601(6)
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierDepositExternalAttestation
      ) do
        now = Time.current
        attestation = SupplierDepositExternalAttestation.create!(
          agency_id: commitment.agency_id,
          departure_id: commitment.departure_id,
          supplier_arrangement_id: commitment.supplier_arrangement_id,
          supplier_arrangement_version_id: commitment.supplier_arrangement_version_id,
          supplier_deposit_requirement_tranche: tranche,
          supplier_commitment: commitment,
          attested_amount_minor_units: tranche.current_amount_minor_units,
          currency: tranche.currency,
          confirmed_complete: true,
          note: @note,
          actor: @actor,
          occurred_at: occurred || now,
          recorded_at: now
        )
        SupplierCommitmentDisposition.create!(
          agency_id: commitment.agency_id,
          departure_id: commitment.departure_id,
          supplier_arrangement_id: commitment.supplier_arrangement_id,
          supplier_arrangement_version_id: commitment.supplier_arrangement_version_id,
          supplier_commitment: commitment,
          outcome: "handled_externally",
          reason: @note,
          supplier_deposit_external_attestation: attestation,
          accepted_risk_acknowledged: false,
          actor: @actor,
          occurred_at: occurred || now,
          recorded_at: now
        )
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.deposit_attested_external",
          details: {
            "supplier_commitment_id" => commitment.id,
            "supplier_deposit_requirement_tranche_id" => tranche.id,
            "supplier_deposit_external_attestation_id" => attestation.id,
            "attested_amount_minor_units" => attestation.attested_amount_minor_units,
            "currency" => attestation.currency
          }
        )
        attestation
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  end

  private

  def normalize_optional_occurred_at(value)
    return nil if value.blank?
    return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)

    Time.zone.parse(value.to_s).tap do |parsed|
      raise Error.new("occurred_at is not a valid time.", code: :invalid) if parsed.blank?
    end
  rescue ArgumentError, TypeError
    raise Error.new("occurred_at is not a valid time.", code: :invalid)
  end
end
