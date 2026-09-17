class RemoveSupplierCostDefinition < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, definition:, source_lock_version:)
    @agency, @actor, @definition, @source_lock_version = agency, actor, definition, source_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, = cost_graph!(@definition)
        ensure_cost_cleanup_edit!(departure, arrangement, version)
        source = lock_source!(version, @definition.supplier_cost_source)
        ensure_current_lock_version!(source, @source_lock_version)
        definition = lock_definition!(source, @definition)
        details = {
          "supplier_cost_source_id" => source.id, "supplier_cost_definition_id" => definition.id,
          "stage" => definition.stage, "mode" => definition.mode, "status" => definition.status
        }
        destroy_definition_graph!(definition)
        source.touch
        audit_cost!("supplier_arrangement.cost_definition_removed", arrangement, version, details)
        Result.new(status: :updated, record: source)
      end
    end
  end
end
