# frozen_string_literal: true

class DisposeSupplierCommitmentsWithEvidence < AgencyCommand
  include ArrangementCommandSupport

  EVIDENCE_OUTCOMES = %w[satisfied released].freeze

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

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      departure = lock_departure_for!(arrangement.departure_id)
      confirmation = arrangement.supplier_confirmations.lock.find(@confirmation.id)
      version_id = confirmation.supplier_arrangement_version_id

      payload = {
        outcome: @outcome,
        supplier_confirmation_id: confirmation.id,
        supplier_commitment_ids: @commitment_ids.sort,
        supplier_arrangement_id: arrangement.id,
        supplier_arrangement_version_id: version_id
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierCommitmentEvidenceCoverage
      ) do
        commitments = lock_open_commitments!(arrangement, confirmation)
        now = Time.current
        occurred = @occurred_at.presence || now
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
          SupplierCommitmentDisposition.create!(
            owner.merge(
              supplier_commitment: commitment,
              outcome: @outcome,
              supplier_commitment_evidence_coverage: coverage,
              actor: @actor,
              occurred_at: occurred,
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
    confirmation.agency_id == commitment.agency_id &&
      confirmation.departure_id == commitment.departure_id &&
      confirmation.supplier_arrangement_id == commitment.supplier_arrangement_id &&
      confirmation.supplier_arrangement_version_id == commitment.supplier_arrangement_version_id
  end

  def owner_attrs(commitment)
    {
      agency_id: commitment.agency_id,
      departure_id: commitment.departure_id,
      supplier_arrangement_id: commitment.supplier_arrangement_id,
      supplier_arrangement_version_id: commitment.supplier_arrangement_version_id
    }
  end
end
