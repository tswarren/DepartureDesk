class CreateSupplierCostSetup < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, arrangement:, source_attributes:, definition_attributes:,
    component_attributes: nil, base_links: nil, version_lock_version:, idempotency_key:)
    @agency = agency
    @actor = actor
    @arrangement = arrangement
    @source_attributes = source_attributes
    @definition_attributes = definition_attributes
    @component_attributes = component_attributes
    @base_links = base_links
    @version_lock_version = version_lock_version
    @idempotency_key = idempotency_key
  end

  def call
    raise NotImplementedError, "CreateSupplierCostSetup is implemented in a later M3D.0 phase"
  end
end
