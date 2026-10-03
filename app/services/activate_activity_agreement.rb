# frozen_string_literal: true

class ActivateActivityAgreement < AgencyCommand
  def initialize(agency:, actor:, arrangement:, version:, idempotency_key:,
    arrangement_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @version = version
    @idempotency_key = idempotency_key
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    review = CompileActivityAgreement.new(
      agency: @agency, departure: @arrangement.departure, arrangement: @arrangement, version: @version
    ).call
    unless review.activation_allowed
      raise AgencyCommand::Error.new(
        review.activation_blocker.presence || "This Activity agreement is not ready to activate.",
        code: :invalid
      )
    end
    confirmation = SupplierConfirmation.find_by!(supplier_arrangement_version_id: @version.id)
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: @version,
      idempotency_key: @idempotency_key,
      arrangement_lock_version: @arrangement_lock_version,
      version_lock_version: @version_lock_version,
      existing_confirmation_id: confirmation.id,
      cost_source_coverage_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      elapsed_deadlines_acknowledged: false
    ).call
  end
end
