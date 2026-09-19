# frozen_string_literal: true

class DisqualifySupplierCommitmentFromEvidenceCoverage < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, coverage:, commitment:, reason:, idempotency_key:,
    disposition_id:, occurred_at: nil)
    @agency = agency
    @actor = actor
    @coverage = coverage
    @commitment = commitment
    @disposition_id = disposition_id.to_s.presence
    @reason = reason.to_s.strip
    @idempotency_key = idempotency_key
    @occurred_at = occurred_at
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Enter a disqualification reason.", code: :invalid) if @reason.blank?
    raise Error.new("That commitment is not currently closed by this evidence coverage.", code: :invalid) if @disposition_id.blank?

    occurred = normalize_optional_occurred_at(@occurred_at)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!

      coverage_row = SupplierCommitmentEvidenceCoverage.find_by!(id: @coverage.id, agency_id: @agency.id)
      commitment_row = SupplierCommitment.find_by!(id: @commitment.id, agency_id: @agency.id)
      arrangement_row = @agency.supplier_arrangements.find(commitment_row.supplier_arrangement_id)

      payload = {
        supplier_commitment_evidence_coverage_id: coverage_row.id,
        supplier_commitment_id: commitment_row.id,
        supplier_commitment_disposition_id: @disposition_id,
        reason: @reason,
        occurred_at: occurred&.utc&.iso8601(6)
      }

      lock_suppliers_in_uuid_order!(commitment_row.committed_supplier_id)
      lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      coverage = arrangement.supplier_commitment_evidence_coverages.lock.find(coverage_row.id)
      commitment = arrangement.supplier_commitments.lock.find(commitment_row.id)
      disposition = commitment.supplier_commitment_dispositions.lock.find(@disposition_id)

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierCommitmentEvidenceMemberDisqualification
      ) do
        if coverage.supplier_commitment_evidence_coverage_revocation.present?
          raise Error.new("That evidence coverage is already revoked.", code: :invalid_state)
        end
        if commitment.reload.open_state?
          raise Error.new("That commitment is already open.", code: :invalid_state)
        end
        unless disposition.reload.current? && disposition.supplier_commitment_evidence_coverage_id == coverage.id
          raise Error.new("That commitment is not currently closed by this evidence coverage.", code: :invalid_state)
        end

        now = Time.current
        occurred_at = occurred || now
        reopening = SupplierCommitmentReopening.create!(
          agency_id: commitment.agency_id,
          departure_id: commitment.departure_id,
          supplier_arrangement_id: commitment.supplier_arrangement_id,
          supplier_arrangement_version_id: commitment.supplier_arrangement_version_id,
          supplier_commitment: commitment,
          supplier_commitment_disposition: disposition,
          reason: @reason,
          actor: @actor,
          occurred_at: occurred_at,
          recorded_at: now
        )
        disqualification = SupplierCommitmentEvidenceMemberDisqualification.create!(
          agency_id: commitment.agency_id,
          departure_id: commitment.departure_id,
          supplier_arrangement_id: commitment.supplier_arrangement_id,
          supplier_arrangement_version_id: commitment.supplier_arrangement_version_id,
          supplier_commitment_evidence_coverage: coverage,
          supplier_commitment: commitment,
          supplier_commitment_disposition: disposition,
          supplier_commitment_reopening: reopening,
          reason: @reason,
          actor: @actor,
          occurred_at: occurred_at,
          recorded_at: now
        )
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.evidence_member_disqualified",
          details: {
            "supplier_commitment_evidence_coverage_id" => coverage.id,
            "supplier_commitment_id" => commitment.id,
            "supplier_commitment_disposition_id" => disposition.id,
            "supplier_commitment_reopening_id" => reopening.id,
            "reason" => @reason
          }
        )
        disqualification
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
