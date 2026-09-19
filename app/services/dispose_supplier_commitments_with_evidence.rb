# frozen_string_literal: true

class DisposeSupplierCommitmentsWithEvidence < AgencyCommand
  include ArrangementCommandSupport

  EVIDENCE_OUTCOMES = %w[satisfied released].freeze
  RELEASE_EVIDENCE_KINDS = SupplierConfirmation::RELEASE_EVIDENCE_KINDS
  SATISFACTION_EVIDENCE_KINDS = SupplierConfirmation::BOOKING_EVIDENCE_KINDS

  def initialize(agency:, actor:, arrangement:, confirmation:, commitment_ids:, outcome:,
    idempotency_key:, occurred_at: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @confirmation = confirmation
    @commitment_ids = Array(commitment_ids).map(&:to_s).uniq
    @outcome = outcome.to_s
    @idempotency_key = idempotency_key
    @occurred_at = occurred_at
  end

  def call
    ensure_arrangement_actor!
    unless EVIDENCE_OUTCOMES.include?(@outcome)
      raise Error.new("Choose satisfied or released.", code: :invalid)
    end
    if @commitment_ids.empty?
      raise Error.new("Select at least one open commitment.", code: :invalid)
    end

    occurred = normalize_optional_occurred_at(@occurred_at)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!

      arrangement_row = @agency.supplier_arrangements.find(@arrangement.id)
      confirmation_row = arrangement_row.supplier_confirmations.find(@confirmation.id)
      commitment_rows = arrangement_row.supplier_commitments.where(id: @commitment_ids).to_a
      if commitment_rows.size != @commitment_ids.size
        raise Error.new("One or more commitments could not be found.", code: :not_found)
      end

      lock_suppliers_in_uuid_order!(
        commitment_rows.map(&:committed_supplier_id) + [ confirmation_row.confirming_supplier_id ]
      )
      lock_departure_for!(arrangement_row.departure_id)
      arrangement = lock_arrangement_for!(arrangement_row)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      confirmation = arrangement.supplier_confirmations.lock.find(confirmation_row.id)
      version_id = confirmation.supplier_arrangement_version_id

      payload = {
        outcome: @outcome,
        supplier_confirmation_id: confirmation.id,
        supplier_commitment_ids: @commitment_ids.sort,
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version_id,
        occurred_at: occurred&.utc&.iso8601(6)
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierCommitmentEvidenceCoverage
      ) do
        commitments = lock_open_commitments!(arrangement, confirmation)
        now = Time.current
        occurred_at = occurred || now
        owner = owner_attrs(commitments.first)
        coverage = SupplierCommitmentEvidenceCoverage.create!(
          owner.merge(
            supplier_confirmation: confirmation,
            purpose: @outcome,
            actor: @actor,
            recorded_at: now
          )
        )
        commitments.each do |commitment|
          SupplierCommitmentEvidenceCoverageMember.create!(
            owner.merge(
              supplier_commitment_evidence_coverage: coverage,
              supplier_commitment: commitment
            )
          )
        end
        commitments.each do |commitment|
          SupplierCommitmentDisposition.create!(
            owner.merge(
              supplier_commitment: commitment,
              outcome: @outcome,
              supplier_commitment_evidence_coverage: coverage,
              actor: @actor,
              occurred_at: occurred_at,
              recorded_at: now,
              accepted_risk_acknowledged: false
            )
          )
        end
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.commitments_disposed",
          details: {
            "outcome" => @outcome,
            "supplier_confirmation_id" => confirmation.id,
            "supplier_commitment_ids" => commitments.map(&:id),
            "supplier_commitment_evidence_coverage_id" => coverage.id
          }
        )
        rebuild_exposure_projection_already_locked!(arrangement)
        coverage
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  end

  private

  def lock_open_commitments!(arrangement, confirmation)
    commitments = arrangement.supplier_commitments.lock
      .where(id: @commitment_ids)
      .order(:id)
      .to_a
    if commitments.size != @commitment_ids.size
      raise Error.new("One or more commitments could not be found.", code: :not_found)
    end

    version_ids = commitments.map(&:supplier_arrangement_version_id).uniq
    if version_ids.size != 1
      raise Error.new("Commitments must share one exact Arrangement version.", code: :invalid)
    end
    if commitments.any? { |commitment| commitment.agency_id != @agency.id }
      raise Error.new("One or more commitments could not be found.", code: :not_found)
    end

    commitments.each do |commitment|
      unless commitment.open_state?
        raise Error.new("That commitment is no longer open.", code: :invalid_state)
      end
      unless confirmation_compatible?(commitment, confirmation)
        raise Error.new("That evidence is not compatible with the selected commitment.", code: :invalid)
      end
    end
    commitments
  end

  def confirmation_compatible?(commitment, confirmation)
    return false unless confirmation.agency_id == commitment.agency_id
    return false unless confirmation.departure_id == commitment.departure_id
    return false unless confirmation.supplier_arrangement_id == commitment.supplier_arrangement_id
    return false unless confirmation.supplier_arrangement_version_id == commitment.supplier_arrangement_version_id
    return false unless confirmation.confirming_supplier_id == commitment.committed_supplier_id
    return false if commitment.supplier_confirmation_id == confirmation.id

    case @outcome
    when "released"
      RELEASE_EVIDENCE_KINDS.include?(confirmation.evidence_kind)
    when "satisfied"
      SATISFACTION_EVIDENCE_KINDS.include?(confirmation.evidence_kind)
    else
      false
    end
  end

  def owner_attrs(commitment)
    {
      agency_id: commitment.agency_id,
      departure_id: commitment.departure_id,
      supplier_arrangement_id: commitment.supplier_arrangement_id,
      supplier_arrangement_version_id: commitment.supplier_arrangement_version_id
    }
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
