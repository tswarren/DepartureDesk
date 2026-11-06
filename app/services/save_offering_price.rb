# Sets one client price on an option (BKG-21): an occupancy position (or
# any), an optional traveler type, and an amount parsed strictly in the
# offering currency (ADR 0001). Saving an existing row's position and type
# updates its amount; changing a price never touches a booking (BKG-23).
class SaveOfferingPrice < AgencyCommand
  include OfferingCommandSupport

  def initialize(agency:, actor:, departure:, offering:, option:, attributes:)
    @agency = agency
    @actor = actor
    @departure = departure
    @offering = offering
    @option = option
    @attributes = clean(attributes, %w[occupancy_position traveler_type_id amount])
  end

  def call
    ensure_departure_actor!(:manage_departures)

    ActiveRecord::Base.transaction do
      departure = lock_offering_context!
      offering = lock_offering!(departure)
      option = OfferingOption.joins(:choice).where(offering_choices: { offering_id: offering.id }).lock.find(@option.id)
      position = @attributes["occupancy_position"]
      raise Error.new("Choose an occupancy position.", code: :invalid) unless OfferingPrice::POSITIONS.include?(position)

      traveler_type = traveler_type!
      price = option.prices.find_or_initialize_by(occupancy_position: position, traveler_type:) { |row| row.assign_attributes(agency: @agency, currency: offering.currency) }
      creating = price.new_record?
      price.amount_minor_units = amount!(offering.currency)
      return Result.new(status: :noop, record: price) if !creating && !price.changed?

      previous = price.amount_minor_units_was
      price.save!
      audit_departure!(departure, "departure.offering_price_set",
        "offering_option_id" => option.id, "offering_price_id" => price.id, "occupancy_position" => position,
        "traveler_type_id" => traveler_type&.id, "amount_minor_units" => price.amount_minor_units, "previous_amount_minor_units" => (previous unless creating))
      Result.new(status: creating ? :created : :updated, record: price)
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def traveler_type!
    return nil if @attributes["traveler_type_id"].blank?

    @agency.traveler_types.find_by(id: parse_optional_uuid(@attributes["traveler_type_id"], "Traveler type")) or
      raise Error.new("Choose one of the agency's traveler types.", code: :invalid)
  end

  def amount!(currency)
    MoneyInput.minor_units(@attributes["amount"], currency) or raise Error.new("Amount is required; enter 0 for no charge.", code: :invalid)
  rescue MoneyInput::Invalid
    raise Error.new("Amount must be an amount in #{currency}, such as 1234.50.", code: :invalid)
  end
end
