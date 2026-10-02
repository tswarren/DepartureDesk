# frozen_string_literal: true

class RecordHotelSupplierConfirmation < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, version:, arrangement_item:, idempotency_key:,
    evidence_attributes:, identifier_attributes: nil, duplicate_acknowledgement_token: nil)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @item = arrangement_item
    @idempotency_key = idempotency_key
    @evidence_attributes = evidence_attributes
    @identifier_attributes = identifier_attributes
    @duplicate_acknowledgement_token = duplicate_acknowledgement_token
  end

  def call
    ensure_arrangement_actor!
    key = normalize_idempotency_key(@idempotency_key)
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      departure = lock_departure_for!(arrangement.departure_id)
      version = arrangement.versions.lock.find(@version.id)
      item = arrangement.arrangement_items.find(@item.id)
      unless version.draft? && version.arrangement_item_definitions.exists?(arrangement_item_id: item.id, category: "lodging")
        raise Error.new("Hotel confirmation is recorded on the editable lodging draft.", code: :invalid_state)
      end
      if SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
        raise Error.new("This version is already Supplier confirmed.", code: :invalid_state)
      end

      review = CompileHotelActivationReview.new(
        agency: @agency, departure: departure, arrangement: arrangement, version: version, item: item
      ).call
      unless review.confirmation_allowed
        message = review.blockers.map(&:message).uniq.to_sentence.presence ||
          "This Hotel agreement is not ready to confirm."
        raise Error.new(message, code: :invalid)
      end

      idempotent_create!(
        command_name: self.class.name, idempotency_key: key,
        payload: {
          supplier_arrangement_version_id: version.id,
          arrangement_item_id: item.id,
          evidence: @evidence_attributes.to_h,
          identifier: @identifier_attributes.to_h
        },
        result_class: SupplierConfirmation
      ) do
        RecordSupplierConfirmationEvidence.new(
          agency: @agency, actor: @actor, arrangement: arrangement, version: version,
          recorded_at: Time.current, evidence_attributes: @evidence_attributes,
          identifier_attributes: @identifier_attributes,
          duplicate_acknowledgement_token: @duplicate_acknowledgement_token
        ).call.record
      end
    end
  end
end
