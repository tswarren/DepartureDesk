# Removes one row from a Draft arrangement's supplier rate table (SUP-35).
class RemoveSupplierRateLine < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, rate_line:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @rate_line = rate_line
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      raise Error.new("The rate table can change only while the arrangement is a draft.", code: :invalid_state) unless arrangement.draft?

      line = arrangement.rate_lines.lock.find(@rate_line.id)
      line.destroy!
      audit!(
        agency: @agency, action: "supplier_arrangement.rate_line_removed", subject: arrangement, actor: @actor,
        details: { "supplier_rate_line_id" => line.id, "inventory_group_id" => line.inventory_group_id,
                   "occupancy_position" => line.occupancy_position, "traveler_type_id" => line.traveler_type_id }
      )
      Result.new(status: :updated, record: arrangement)
    end
  end
end
