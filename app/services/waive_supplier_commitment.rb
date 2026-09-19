# frozen_string_literal: true

class WaiveSupplierCommitment < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, commitment:, reason:, accepted_risk_acknowledged:,
    idempotency_key:, occurred_at: nil)
    @agency = agency
    @actor = actor
    @commitment = commitment
    @reason = reason.to_s.strip
    @accepted_risk_acknowledged = ActiveModel::Type::Boolean.new.cast(accepted_risk_acknowledged)
    @idempotency_key = idempotency_key
    @occurred_at = occurred_at
  end

  def call
    ensure_arrangement_actor!(:override_supplier_planning_terms)
    raise Error.new("Enter a waiver reason.", code: :invalid) if @reason.blank?
    unless @accepted_risk_acknowledged
      raise Error.new("Acknowledge the accepted risk to waive this commitment.", code: :invalid)
    end

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!(:override_supplier_planning_terms)
      arrangement = lock_arrangement_for!(@commitment.supplier_arrangement_id)
      raise Error.new("That supplier arrangement has ended.", code: :invalid_state) if arrangement.ended?
      raise Error.new("That supplier arrangement has been abandoned.", code: :invalid_state) if arrangement.abandoned?

      commitment = arrangement.supplier_commitments.lock.find(@commitment.id)

      payload = {
        outcome: "waived",
        supplier_commitment_id: commitment.id,
        reason: @reason,
        accepted_risk_acknowledged: true
      }

      idempotent_create!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload:,
        result_class: SupplierCommitmentDisposition
      ) do
        unless commitment.reload.open_state?
          raise Error.new("That commitment is no longer open.", code: :invalid_state)
        end
        now = Time.current
        disposition = SupplierCommitmentDisposition.create!(
          agency_id: commitment.agency_id,
          departure_id: commitment.departure_id,
          supplier_arrangement_id: commitment.supplier_arrangement_id,
          supplier_arrangement_version_id: commitment.supplier_arrangement_version_id,
          supplier_commitment: commitment,
          outcome: "waived",
          reason: @reason,
          accepted_risk_acknowledged: true,
          actor: @actor,
          occurred_at: @occurred_at.presence || now,
          recorded_at: now
        )
        audit!(
          agency: @agency, actor: @actor, subject: arrangement,
          action: "supplier_arrangement.commitments_disposed",
          details: {
            "outcome" => "waived",
            "supplier_commitment_ids" => [ commitment.id ],
            "supplier_commitment_disposition_id" => disposition.id,
            "reason" => @reason
          }
        )
        disposition
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence.presence || error.message, code: :invalid)
  end
end
