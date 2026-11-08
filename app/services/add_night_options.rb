# Adds extra hotel nights to a package (BKG-14 to BKG-16, BKG-21): an
# add-on choice made per unit with any number of options, one per night
# and room type drawing on that night's group (INV-13). Each option can
# start with the prices of the included room of the same type, copied once
# and then its own. One transaction through the commands that own each
# record.
class AddNightOptions < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, offering:, name:, groups:, price_from: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @name = name
    @groups = groups
    @price_from = price_from
  end

  def call
    ensure_departure_actor!(:manage_departures)
    raise Error.new("Choose at least one night and room type.", code: :invalid) if @groups.empty?

    ActiveRecord::Base.transaction do
      choice = SaveOfferingChoice.new(agency: @agency, actor: @actor, departure: @departure, offering: @offering,
        attributes: { name: @name, role: "add_on", scope: "per_unit", pattern: "optional_multiple" }).call.record
      @groups.sort_by { |group| [ group.starts_on, group.label ] }.each do |group|
        option = SaveOfferingOption.new(agency: @agency, actor: @actor, departure: @departure, offering: @offering, choice:,
          attributes: { label: group.label, inventory_group_id: group.id }).call.record
        copy_prices!(option, group)
      end
      Result.new(status: :created, record: choice)
    end
  end

  private

  def copy_prices!(option, group)
    source = @price_from&.options&.find { |candidate| candidate.inventory_group.night_kind == group.night_kind }
    return unless source

    limit = group.positions_per_unit
    source.prices.each do |price|
      next if limit && price.guest_number && price.guest_number > limit

      SaveOfferingPrice.new(agency: @agency, actor: @actor, departure: @departure, offering: @offering, option:,
        attributes: { occupancy_position: price.occupancy_position, traveler_type_id: price.traveler_type_id,
                      amount: MoneyInput.display(price.amount_minor_units, price.currency).delete(",") }).call
    end
  end
end
