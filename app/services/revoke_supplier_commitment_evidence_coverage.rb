# frozen_string_literal: true

class RevokeSupplierCommitmentEvidenceCoverage < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, coverage:, reason:, idempotency_key:, occurred_at: nil)
    @agency = agency
    @actor = actor
    @coverage = coverage
    @reason = reason.to_s.strip
    @idempotency_key = idempotency_key
    @occurred_at = occurred_at
  end

  def call
    ensure_arrangement_actor!
    raise Error.new("Enter a revocation reason.", code: :invalid) if @reason.blank?

    occurred = normalize_optional_occurred_at(@occurred_at)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!

      coverage_row = SupplierCommitmentEvidenceCoverage.find_by!(id: @coverage.id, agency_id: @agency.id)
      arrangement_row = @agency.supplier_arrangements.find(coverage_row.supplier_arrangement_id)
      confirmation = SupplierConfirmation.find_by!(
        id: coverage_row.supplier_confirmation_id, agency_id: @agency.id
      )
      dependent_commitments = current_dependent_commitments(coverage_row)

      lock_suppliers_in_uuid_order!(
        dependent_commitments.map(&:committed_supplier_id) + [ confirmation.confirming_supplier_id ]
      )
      lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      coverage = arrangement.supplier_commitment_evidence_coverages.lock.find(coverage_row.id)
      if coverage.supplier_commitment_evidence_coverage_revocation.present?
        raise Error.new("That evidence coverage is already revoked.", code: :invalid_state)
      end

      commitments = SupplierCommitment.where(id: dependent_commitments.map(&:id), agency_id: @agency.id)
        .order(:id).lock.to_a

      payload = {
        supplier_commitment_evidence_coverage_id: coverage.id,
        supplier_commitment_ids: commitments.map(&:id).sort,
        reason: @reason,
        occurred_at: occurred&.utc&.iso8601(6)
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierCommitmentEvidenceCoverageRevocation
      ) do
        if coverage.reload.supplier_commitment_evidence_coverage_revocation.present?
          raise Error.new("That evidence coverage is already revoked.", code: :invalid_state)
        end

        now = Time.current
        occurred_at = occurred || now
        reopening_ids = []
        commitments.each do |commitment|
          disposition = commitment.current_disposition
          unless disposition&.supplier_commitment_evidence_coverage_id == coverage.id && disposition.current?
            raise Error.new("Evidence coverage dependents changed. Reload and try again.", code: :conflict)
          end

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
          reopening_ids << reopening.id
        end

        revocation = SupplierCommitmentEvidenceCoverageRevocation.create!(
          agency_id: coverage.agency_id,
          departure_id: coverage.departure_id,
          supplier_arrangement_id: coverage.supplier_arrangement_id,
          supplier_arrangement_version_id: coverage.supplier_arrangement_version_id,
          supplier_commitment_evidence_coverage: coverage,
          reason: @reason,
          actor: @actor,
          occurred_at: occurred_at,
          recorded_at: now
        )
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.evidence_coverage_revoked",
          details: {
            "supplier_commitment_evidence_coverage_id" => coverage.id,
            "supplier_commitment_ids" => commitments.map(&:id),
            "supplier_commitment_reopening_ids" => reopening_ids,
            "reason" => @reason
          }
        )
        revocation
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  end

  private

  def current_dependent_commitments(coverage)
    coverage.supplier_commitment_dispositions.includes(:supplier_commitment_reopening, :supplier_commitment)
      .select(&:current?)
      .map(&:supplier_commitment)
      .uniq
  end

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
