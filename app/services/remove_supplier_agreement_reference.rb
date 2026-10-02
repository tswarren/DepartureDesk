# frozen_string_literal: true

class RemoveSupplierAgreementReference < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, reference:, lock_version:)
    @agency = agency
    @actor = actor
    @reference = reference
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        reference = SupplierAgreementReference.where(agency: @agency).lock.find(@reference.id)
        _departure, arrangement, version = lock_departure_arrangement_version!(reference.supplier_arrangement)
        unless version.id == reference.supplier_arrangement_version_id
          raise Error.new("Agreement references are removed from the editable draft.", code: :invalid_state)
        end
        if SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
          raise Error.new(
            "Agreement references are immutable after Supplier confirmation.",
            code: :invalid_state
          )
        end

        ensure_current_lock_version!(reference, @lock_version)
        details = {
          "supplier_agreement_reference_id" => reference.id,
          "arrangement_item_id" => reference.arrangement_item_id,
          "kind" => reference.kind
        }
        reference.destroy!
        audit_cost!("supplier_arrangement.agreement_reference_removed", arrangement, version, details)
        Result.new(status: :destroyed, record: reference)
      end
    end
  end
end
