class ConfigureCapacityPairWithPool < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, item:, service_occurrence:, supplier_resource:,
    pool_attributes:, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @item = item
    @service_occurrence = service_occurrence
    @supplier_resource = supplier_resource
    @pool_attributes = pool_attributes
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    raise NotImplementedError, "ConfigureCapacityPairWithPool is implemented in a later M3D.0 phase"
  end
end
