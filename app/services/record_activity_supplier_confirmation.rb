# frozen_string_literal: true

class RecordActivitySupplierConfirmation < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, version:, idempotency_key:, evidence_attributes:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @idempotency_key = idempotency_key
    @evidence_attributes = evidence_attributes
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure = lock_departure_for!(@arrangement.departure_id)
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.versions.lock.find(@version.id)
      unless version.draft? && version.arrangement_item_definitions.exists?(category: "activity_attraction")
        raise Error.new("Activity confirmation is recorded on the editable Activity draft.", code: :invalid_state)
      end
      if SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
        raise Error.new("This version is already Supplier confirmed.", code: :invalid_state)
      end
      review = CompileActivityAgreement.new(agency: @agency, departure:, arrangement:, version:).call
      unless review.confirmation_allowed
        raise Error.new(review.confirmation_blocker.presence || ActivityAgreementShape::ADVANCED, code: :invalid)
      end

      idempotent_create!(
        command_name: self.class.name, idempotency_key: @idempotency_key,
        payload: { supplier_arrangement_version_id: version.id, evidence: @evidence_attributes.to_h },
        result_class: SupplierConfirmation
      ) do
        RecordSupplierConfirmationEvidence.new(
          agency: @agency, actor: @actor, arrangement:, version:,
          recorded_at: Time.current, evidence_attributes: @evidence_attributes
        ).call.record
      end
    end
  end
end
