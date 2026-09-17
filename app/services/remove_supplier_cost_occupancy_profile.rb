class RemoveSupplierCostOccupancyProfile < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, profile:, assumption_lock_version:)
    @agency, @actor, @profile, @assumption_lock_version = agency, actor, profile, assumption_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, = cost_graph!(@profile)
        ensure_cost_cleanup_edit!(departure, arrangement, version)
        assumption = version.supplier_cost_usage_assumptions.lock.find(@profile.supplier_cost_usage_assumption_id)
        ensure_current_lock_version!(assumption, @assumption_lock_version)
        profile = assumption.supplier_cost_occupancy_profiles.lock.find(@profile.id)
        details = {
          "supplier_cost_usage_assumption_id" => assumption.id,
          "supplier_cost_occupancy_profile_id" => profile.id,
          "arrangement_item_id" => assumption.arrangement_item_id,
          "label" => profile.label, "position" => profile.position
        }
        profile.supplier_cost_occupancy_profile_positions.order(:id).lock.each(&:destroy!)
        profile.destroy!
        remaining = assumption.supplier_cost_occupancy_profiles.order(:position, :id).lock.to_a
        remaining.each_with_index { |entry, index| entry.update!(position: index + 1) }
        assumption.touch
        audit_cost!("supplier_arrangement.cost_occupancy_profile_removed", arrangement, version, details)
        Result.new(status: :updated, record: assumption)
      end
    end
  end
end
