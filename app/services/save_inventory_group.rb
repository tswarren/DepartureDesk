# Adds or edits an inventory group (INV-01 to INV-04, SUP-15). On a Draft
# arrangement every field can change. Once confirmed, only the label can:
# structural changes need replacement inventory (INV-32).
class SaveInventoryGroup < AgencyCommand
  include ArrangementCommandSupport

  FIELDS = %w[
    label service_category representation availability_promise quantity positions_per_unit
    starts_on starts_at_time ends_on ends_at_time time_zone position
  ].freeze
  DESCRIPTIVE_FIELDS = %w[label].freeze

  def initialize(agency:, actor:, departure:, arrangement:, attributes:, group: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @arrangement = arrangement
    @group = group
    @attributes = attributes.to_h.stringify_keys.slice(*FIELDS).transform_values { |value| value.is_a?(String) ? value.strip.presence : value }
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_arrangements)

    ActiveRecord::Base.transaction do
      departure = lock_arrangement_context!
      arrangement = lock_arrangement!(departure)
      raise Error.new("A cancelled arrangement can't change.", code: :invalid_state) if arrangement.cancelled?

      group = @group ? locked_group(arrangement) : new_group(arrangement, departure)
      creating = group.new_record?
      raise Error.new("Inventory can be added only while the arrangement is a draft.", code: :invalid_state) if creating && !arrangement.draft?

      attrs = @attributes
      unless arrangement.draft?
        structural = attrs.keys - DESCRIPTIVE_FIELDS
        if structural.any? { |field| group.public_send(field).to_s != attrs[field].to_s }
          raise Error.new("After confirmation only the label can change; add replacement inventory for anything else.", code: :invalid_state)
        end
        attrs = attrs.slice(*DESCRIPTIVE_FIELDS)
      end
      group.assign_attributes(attrs)
      changed = group.changed - %w[lock_version updated_at]
      return Result.new(status: :noop, record: group) if !creating && changed.empty?

      group.save!
      audit!(
        agency: @agency, action: creating ? "supplier_arrangement.inventory_group_added" : "supplier_arrangement.inventory_group_updated",
        subject: arrangement, actor: @actor,
        details: { "inventory_group_id" => group.id, "label" => group.label, "changed" => changed.sort }
      )
      Result.new(status: creating ? :created : :updated, record: group)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  rescue ArgumentError => error
    raise Error.new(error.message, code: :invalid)
  end

  private

  def locked_group(arrangement)
    arrangement.inventory_groups.lock.find(@group.id).tap do |group|
      raise Error.new(STALE_MESSAGE, code: :conflict) if @lock_version.blank? || group.lock_version != @lock_version.to_i
    end
  end

  def new_group(arrangement, departure)
    category = @attributes["service_category"]
    arrangement.inventory_groups.new(
      agency: @agency,
      representation: InventoryGroup::DEFAULT_REPRESENTATIONS[category] || "unit_shells",
      availability_promise: arrangement.default_availability_promise,
      time_zone: departure.time_zone,
      position: arrangement.inventory_groups.maximum(:position).to_i + 1
    )
  end
end
