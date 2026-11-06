# Removes an inventory group from a Draft arrangement. A confirmed group has
# shells or a pool and is never removed (INV-32).
class RemoveInventoryGroup < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, group:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @group = group
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_draft!(arrangement)
      group = arrangement.inventory_groups.lock.find(@group.id)
      group.capacity_rules.delete_all(:delete_all)
      group.rate_lines.delete_all(:delete_all)
      group.deadlines.update_all(inventory_group_id: nil)
      group.destroy!
      audit!(
        agency: @agency, action: "supplier_arrangement.inventory_group_removed", subject: arrangement, actor: @actor,
        details: { "inventory_group_id" => group.id, "label" => group.label }
      )
      Result.new(status: :updated, record: arrangement)
    end
  end
end
