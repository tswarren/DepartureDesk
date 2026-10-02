# frozen_string_literal: true

class ReviseConfirmedHotelAgreement < AgencyCommand
  def initialize(agency:, actor:, arrangement:, reason:, idempotency_key:,
    arrangement_lock_version:, version_lock_version:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @reason = reason
    @idempotency_key = idempotency_key
    @arrangement_lock_version = arrangement_lock_version
    @version_lock_version = version_lock_version
  end

  def call
    ReviseConfirmedSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      reason: @reason,
      idempotency_key: @idempotency_key,
      arrangement_lock_version: @arrangement_lock_version,
      version_lock_version: @version_lock_version,
      vertical: "lodging",
      command_name: self.class.name
    ).call
  end
end
