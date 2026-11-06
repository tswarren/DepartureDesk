# Removes a cost line from a Draft arrangement, with its shells. A line
# with schedule lines or percentage lines based on it stays.
class RemoveCostLine < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, cost_line:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @cost_line = cost_line
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_draft!(arrangement)
      line = arrangement.cost_lines.lock.find(@cost_line.id)
      if line.schedule_lines.exists? || line.dependent_cost_lines.exists?
        raise Error.new("Remove the schedule lines and percentage lines that use this cost line first.", code: :invalid_state)
      end

      line.cost_line_shells.delete_all
      line.destroy!
      audit!(agency: @agency, action: "supplier_arrangement.cost_line_removed", subject: arrangement, actor: @actor,
        details: { "cost_line_id" => line.id, "amount_minor_units" => line.amount_minor_units })
      Result.new(status: :updated, record: arrangement)
    end
  end
end
