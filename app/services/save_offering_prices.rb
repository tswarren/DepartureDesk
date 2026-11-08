# Saves the cells of one choice's client price grid (S-20, BKG-21): each
# cell sets one amount, in the offering currency, on every occupancy
# position it covers for its option and traveler type, or removes those
# prices when left blank. Only changed cells are sent. Once an option's
# own positions are all priced, an any-position price no guest could reach
# is removed; a group with no stated size keeps it for guests after the 1st. Changing a price never touches a booking (BKG-23).
class SaveOfferingPrices < AgencyCommand
  include OfferingCommandSupport

  Cell = Data.define(:option_id, :positions, :traveler_type_id, :amount, :label)

  def initialize(agency:, actor:, departure:, offering:, choice:, cells:)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @choice = choice
    @cells = cells
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      choice = offering.choices.find(@choice.id)
      options = choice.options.includes(:inventory_group, :prices).lock.index_by(&:id)
      changes = @cells.sum { |cell| save_cell!(departure, offering, options, cell) }
      changes += options.values.sum { |option| tidy!(departure, option) } if choice.made_per_unit?
      Result.new(status: changes.zero? ? :noop : :updated, record: choice)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def save_cell!(departure, offering, options, cell)
    option = options[cell.option_id] or raise Error.new("That option is not in this choice.", code: :not_found)
    traveler_type = cell.traveler_type_id && (@agency.traveler_types.find_by(id: cell.traveler_type_id) or raise Error.new("Choose one of the agency's traveler types.", code: :invalid))
    amount = amount!(cell, offering.currency)
    option.stored_positions_for(cell.positions).sum do |position|
      price = option.prices.find { |row| row.occupancy_position == position && row.traveler_type_id == traveler_type&.id }
      if amount.nil?
        price ? remove!(departure, option, price) : 0
      else
        set!(departure, option, price, position, traveler_type, amount, offering.currency)
      end
    end
  end

  def set!(departure, option, price, position, traveler_type, amount, currency)
    return 0 if price&.amount_minor_units == amount

    previous = price&.amount_minor_units
    price ||= option.prices.build(agency: @agency, occupancy_position: position, traveler_type:, currency:)
    price.amount_minor_units = amount
    price.save!
    audit_departure!(departure, "departure.offering_price_set",
      "offering_option_id" => option.id, "offering_price_id" => price.id, "occupancy_position" => position,
      "traveler_type_id" => traveler_type&.id, "amount_minor_units" => amount, "previous_amount_minor_units" => previous)
    1
  end

  def remove!(departure, option, price)
    option.prices.target.delete(price)
    price.destroy!
    audit_departure!(departure, "departure.offering_price_removed", "offering_price_id" => price.id, "offering_option_id" => option.id)
    1
  end

  # An untyped any-position price no guest can reach once each position has its own.
  def tidy!(departure, option)
    any = option.prices.find { |row| row.occupancy_position == "any" && row.traveler_type_id.nil? }
    return 0 unless any && option.inventory_group.positions_per_unit

    covered = option.prices.select { |row| row.traveler_type_id.nil? }.map(&:occupancy_position)
    (option.priced_positions - covered).empty? ? remove!(departure, option, any) : 0
  end

  def amount!(cell, currency)
    MoneyInput.minor_units(cell.amount, currency)
  rescue MoneyInput::Invalid
    raise Error.new("#{cell.label}: enter an amount in #{currency}, such as 1234.50, or 0 for no charge.", code: :invalid)
  end
end
