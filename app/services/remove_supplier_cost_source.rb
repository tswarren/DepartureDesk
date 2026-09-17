class RemoveSupplierCostSource < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, source:, version_lock_version:)
    @agency, @actor, @source, @version_lock_version = agency, actor, source, version_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, = cost_graph!(@source)
        ensure_cost_cleanup_edit!(departure, arrangement, version)
        ensure_current_lock_version!(version, @version_lock_version)
        source = lock_source!(version, @source)
        details = { "supplier_cost_source_id" => source.id, "charging_supplier_id" => source.charging_supplier_id,
                    "position" => source.position }.merge(source_context(source))
        source.supplier_cost_definitions.order(:id).lock.each { |definition| destroy_definition_graph!(definition) }
        source.destroy!
        bump_version!(version)
        audit_cost!("supplier_arrangement.cost_source_removed", arrangement, version, details)
        Result.new(status: :updated, record: arrangement)
      end
    end
  end
end
