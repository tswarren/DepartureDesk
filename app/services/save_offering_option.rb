# Adds or edits an option in a choice, drawing on one inventory group of a
# live arrangement on the same Departure (BKG-14, BKG-15).
class SaveOfferingOption < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, offering:, choice:, attributes:, option: nil, lock_version: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @choice = choice
    @option = option
    @attributes = clean(attributes, %w[label description inventory_group_id])
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      choice = offering.choices.find(@choice.id)
      option = if @option
        choice.options.lock.find(@option.id).tap { |record| ensure_version!(record) }
      else
        choice.options.new(agency: @agency, position: choice.options.maximum(:position).to_i + 1)
      end
      creating = option.new_record?
      option.assign_attributes(label: @attributes.fetch("label", option.label), description: @attributes.fetch("description", option.description),
        inventory_group: group(departure, option))
      changed = option.changed - %w[lock_version updated_at position]
      return Result.new(status: :noop, record: option) if !creating && changed.empty?
      if !creating && option.inventory_group_id_changed? && option.choice_selections.exists?
        raise Error.new("Bookings use this option, so it can't draw on another group. Add a new option instead.", code: :invalid_state)
      end
      if !creating && option.inventory_group_id_changed? && option.prices.exists?
        raise Error.new("Remove this option's prices before it draws on another group.", code: :invalid_state)
      end

      option.save!
      audit_departure!(departure, creating ? "departure.offering_option_added" : "departure.offering_option_updated",
        "offering_id" => offering.id, "offering_option_id" => option.id, "inventory_group_id" => option.inventory_group_id, "changed" => changed.sort)
      Result.new(status: creating ? :created : :updated, record: option)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("This choice already has an option for that inventory group.", code: :invalid)
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def group(departure, option)
    return option.inventory_group unless @attributes.key?("inventory_group_id")

    id = parse_optional_uuid(@attributes["inventory_group_id"], "Inventory group")
    group = InventoryGroup.joins(:supplier_arrangement)
      .where(supplier_arrangements: { departure_id: departure.id, agency_id: @agency.id }).where.not(supplier_arrangements: { status: "cancelled" })
      .find_by(id:)
    raise Error.new("Choose an inventory group from this departure's arrangements.", code: :invalid) if group.nil?

    group
  end
end
