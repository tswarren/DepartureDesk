# frozen_string_literal: true

class RemoveSupplierAgreementReferenceAbsence < AgencyCommand
  include SupplierTermRecordSupport

  def initialize(agency:, actor:, absence:, lock_version:)
    @agency = agency
    @actor = actor
    @absence = absence
    @lock_version = lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        absence = SupplierAgreementReferenceAbsence.where(agency: @agency).lock.find(@absence.id)
        _departure, arrangement, version = lock_departure_arrangement_version!(absence.supplier_arrangement)
        unless version.id == absence.supplier_arrangement_version_id
          raise Error.new("Agreement references are removed from the editable draft.", code: :invalid_state)
        end
        if SupplierConfirmation.exists?(supplier_arrangement_version_id: version.id)
          raise Error.new(
            "Agreement references are immutable after Supplier confirmation.",
            code: :invalid_state
          )
        end

        ensure_current_lock_version!(absence, @lock_version)
        details = {
          "supplier_agreement_reference_absence_id" => absence.id,
          "arrangement_item_id" => absence.arrangement_item_id,
          "kind" => absence.kind
        }
        absence.destroy!
        audit_cost!("supplier_arrangement.agreement_reference_absence_removed", arrangement, version, details)
        Result.new(status: :destroyed, record: absence)
      end
    end
  end
end
