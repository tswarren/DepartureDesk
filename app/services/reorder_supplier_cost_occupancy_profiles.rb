class ReorderSupplierCostOccupancyProfiles < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, assumption:, supplier_cost_occupancy_profile_ids:, assumption_lock_version:)
    @agency, @actor, @assumption = agency, actor, assumption
    @ids, @assumption_lock_version = supplier_cost_occupancy_profile_ids, assumption_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, contractor = cost_graph!(@assumption)
        ensure_cost_ordinary_edit!(departure, arrangement, version, contractor)
        assumption = version.supplier_cost_usage_assumptions.lock.find(@assumption.id)
        ensure_current_lock_version!(assumption, @assumption_lock_version)
        profiles = assumption.supplier_cost_occupancy_profiles.order(:position, :id).lock.to_a
        ids = exact_permutation!(@ids, profiles.map(&:id), "Occupancy profile")
        old = profiles.to_h { |profile| [ profile.id, profile.position ] }
        by_id = profiles.index_by(&:id)
        ids.each_with_index { |id, index| by_id.fetch(id).update!(position: index + 1) }
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_cost_profiles_position_unique IMMEDIATE")
        assumption.touch
        audit_cost!("supplier_arrangement.cost_occupancy_profiles_reordered", arrangement, version, {
          "supplier_cost_usage_assumption_id" => assumption.id,
          "supplier_cost_occupancy_profile_ids" => ids, "old_positions" => old,
          "new_positions" => ids.each_with_index.to_h { |id, i| [ id, i + 1 ] }
        })
        Result.new(status: :updated, record: assumption)
      end
    end
  end
end
