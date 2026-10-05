# frozen_string_literal: true

class RecordActivityFinalCount < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, arrangement:, item:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @item = item
    @idempotency_key = idempotency_key
  end

  def call
    ensure_arrangement_actor!
    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      arrangement = lock_arrangement_for!(@arrangement)
      version = arrangement.governing_version
      deadline = version && ActivityAgreementShape.deadline(version, @item, "final_count_due")
      unless arrangement.active? && deadline
        raise Error.new("The final participant count is recorded on the governing Activity agreement.", code: :invalid_state)
      end
      before = deadline.rule_parameters["date"]
      audit!(
        agency: @agency, action: "supplier_arrangement.activity_final_count_recorded",
        subject: arrangement, actor: @actor,
        details: {
          "supplier_arrangement_id" => arrangement.id,
          "arrangement_item_id" => @item.id,
          "supplier_deadline_definition_id" => deadline.id
        }
      )
      deadline.reload
      if deadline.rule_parameters["date"] != before
        raise Error.new("Recording the final count changed the contractual deadline.", code: :invalid_state)
      end

      deadline
    end
  end
end
