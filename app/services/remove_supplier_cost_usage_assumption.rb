class RemoveSupplierCostUsageAssumption < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, assumption:, lock_version:)
    @agency, @actor, @assumption, @lock_version = agency, actor, assumption, lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, = cost_graph!(@assumption)
        ensure_cost_cleanup_edit!(departure, arrangement, version)
        assumption = version.supplier_cost_usage_assumptions.lock.find(@assumption.id)
        ensure_current_lock_version!(assumption, @lock_version)
        if assumption.supplier_cost_occupancy_profiles.exists?
          raise Error.new("Remove occupancy profiles before removing this assumption.", code: :dependency_exists)
        end
        details = {
          "supplier_cost_usage_assumption_id" => assumption.id,
          "arrangement_item_id" => assumption.arrangement_item_id,
          "service_occurrence_id" => assumption.service_occurrence_id,
          "supplier_resource_id" => assumption.supplier_resource_id
        }
        assumption.destroy!
        audit_cost!("supplier_arrangement.cost_usage_assumption_removed", arrangement, version, details)
        Result.new(status: :updated, record: arrangement)
      end
    end
  end
end
