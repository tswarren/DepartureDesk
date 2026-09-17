class RemoveSupplierCostParticipantCategory < AgencyCommand
  include CostCommandSupport

  def initialize(agency:, actor:, category:, version_lock_version:)
    @agency, @actor, @category, @version_lock_version = agency, actor, category, version_lock_version
  end

  def call
    ensure_arrangement_actor!
    safely_command do
      ActiveRecord::Base.transaction do
        lock_authorized_arrangement_agency!
        departure, arrangement, version, = cost_graph!(@category)
        ensure_cost_cleanup_edit!(departure, arrangement, version)
        ensure_current_lock_version!(version, @version_lock_version)
        category = version.supplier_cost_participant_categories.lock.find(@category.id)
        if category.supplier_cost_components.exists? || category.supplier_cost_occupancy_profile_positions.exists?
          raise Error.new("That category is still used by cost planning.", code: :dependency_exists)
        end
        details = {
          "supplier_cost_participant_category_id" => category.id,
          "arrangement_item_id" => category.arrangement_item_id,
          "label" => category.label, "position" => category.position
        }
        category.destroy!
        remaining = version.supplier_cost_participant_categories
          .where(arrangement_item_id: category.arrangement_item_id).order(:position, :id).lock.to_a
        remaining.each_with_index { |entry, index| entry.update!(position: index + 1) }
        bump_version!(version)
        audit_cost!("supplier_arrangement.cost_participant_category_removed", arrangement, version, details)
        Result.new(status: :updated, record: arrangement)
      end
    end
  end
end
