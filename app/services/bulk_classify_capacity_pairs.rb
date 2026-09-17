class BulkClassifyCapacityPairs < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, item:, decisions:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @item = item
    @decisions = decisions
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    raise NotImplementedError, "BulkClassifyCapacityPairs is implemented in a later M3D.0 phase"
  end
end
