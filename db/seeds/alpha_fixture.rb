# The Alpha fixture (first-slice charter, Fixture; D-87), loaded by one script
# for development (db/seeds.rb) and for the demonstration-case tests. All names
# are fictional.
#
# Phase 1 seeds only what the app can hold today: the three suppliers and the
# Departure. Each Slice 1 step extends this script with the records it builds.
# Loading is idempotent: records already present in the agency are reused.
module AlphaFixture
  Result = Data.define(:agency, :actor, :suppliers, :departure)

  DEPARTURE_NAME = "Alpha Omega"
  DEPARTURE_DESCRIPTION = "Port Everglades round trip."
  STARTS_ON = Date.new(2027, 11, 6)
  ENDS_ON = Date.new(2027, 11, 13)
  TIME_ZONE = "America/New_York"
  CURRENCY = "USD"

  SUPPLIERS = {
    cruise: { display_name: "Alpha Cruises", categories: [ "cruise_line" ] },
    hotel: { display_name: "Sablewater Harbor Hotel", categories: [ "lodging" ] },
    excursion: { display_name: "Shore Excursions Group", categories: [ "activity_attraction" ] }
  }.freeze

  def self.load!(agency:, actor:, office:)
    suppliers = SUPPLIERS.transform_values { |definition| supplier!(agency, actor, definition) }
    departure = departure!(agency, actor, office)
    Result.new(agency:, actor:, suppliers:, departure:)
  end

  def self.supplier!(agency, actor, definition)
    existing = agency.suppliers.find_by(kind: "organization", display_name: definition.fetch(:display_name))
    return existing if existing

    result = CreateSupplier.new(
      agency:,
      actor:,
      kind: "organization",
      names: { display_name: definition.fetch(:display_name) },
      categories: definition.fetch(:categories)
    ).call
    created!(result, definition.fetch(:display_name))
  end
  private_class_method :supplier!

  def self.departure!(agency, actor, office)
    existing = agency.departures.find_by(name: DEPARTURE_NAME)
    return existing if existing

    result = CreateDeparture.new(
      agency:,
      actor:,
      attributes: {
        name: DEPARTURE_NAME,
        description: DEPARTURE_DESCRIPTION,
        starts_on: STARTS_ON,
        ends_on: ENDS_ON,
        time_zone: TIME_ZONE,
        operating_currency: CURRENCY,
        responsible_office_id: office.id,
        responsible_agency_user_id: actor.id
      }
    ).call
    created!(result, DEPARTURE_NAME)
  end
  private_class_method :departure!

  def self.created!(result, name)
    return result.record if result.status == :created && result.record

    raise "The Alpha fixture could not create #{name} (#{result.status})."
  end
  private_class_method :created!
end
