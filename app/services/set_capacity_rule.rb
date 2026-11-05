# Names a traveler type that takes part in a group without using capacity,
# or removes that rule (INV-39). Draft only: once confirmed, it's part of
# the supplier's terms.
class SetCapacityRule < AgencyCommand
  include ArrangementCommandSupport

  def initialize(agency:, actor:, departure:, arrangement:, group:, traveler_type_id:, uses_capacity:)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @group = group
    @traveler_type_id = traveler_type_id
    @uses_capacity = ActiveModel::Type::Boolean.new.cast(uses_capacity)
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      ensure_draft!(arrangement)
      group = arrangement.inventory_groups.lock.find(@group.id)
      traveler_type = @agency.traveler_types.find_by(id: parse_optional_uuid(@traveler_type_id, "Traveler type"))
      raise Error.new("Choose a traveler type.", code: :invalid) if traveler_type.nil?

      rule = group.capacity_rules.find_by(traveler_type:)
      if @uses_capacity
        return Result.new(status: :noop, record: group) unless rule

        rule.destroy!
      else
        return Result.new(status: :noop, record: group) if rule

        group.capacity_rules.create!(agency: @agency, traveler_type:, uses_capacity: false)
      end
      audit!(
        agency: @agency, action: "supplier_arrangement.capacity_rule_changed", subject: arrangement, actor: @actor,
        details: { "inventory_group_id" => group.id, "traveler_type_id" => traveler_type.id, "uses_capacity" => @uses_capacity }
      )
      Result.new(status: :updated, record: group)
    end
  end
end
