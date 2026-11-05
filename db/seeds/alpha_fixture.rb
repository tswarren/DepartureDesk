# The Alpha fixture (first-slice charter, Fixture; D-87), loaded by one script
# for development (db/seeds.rb) and for the demonstration-case tests. All names
# are fictional.
#
# Seeds what the app can hold so far: the three suppliers and the Departure,
# which has the loading user as its default task owner, a Proceed decision
# and the Ready to sell status (step 2). Each Slice 1 step extends this script
# with the records it builds.
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

  def self.load!(agency:, actor:)
    suppliers = SUPPLIERS.transform_values { |definition| supplier!(agency, actor, definition) }
    departure = departure!(agency, actor)
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

  def self.departure!(agency, actor)
    departure = agency.departures.find_by(name: DEPARTURE_NAME) || create_departure!(agency, actor)
    if departure.decision_undecided?
      RecordDepartureDecision.new(agency:, actor:, departure:, decision: "proceed", lock_version: departure.lock_version).call
      departure.reload
    end
    if departure.draft?
      MarkDepartureReadyToSell.new(agency:, actor:, departure:, lock_version: departure.lock_version).call
      departure.reload
    end
    departure
  end
  private_class_method :departure!

  def self.create_departure!(agency, actor)
    result = CreateDeparture.new(
      agency:,
      actor:,
      attributes: {
        name: DEPARTURE_NAME,
        description: DEPARTURE_DESCRIPTION,
        starts_on: STARTS_ON,
        ends_on: ENDS_ON,
        time_zone: TIME_ZONE,
        operating_currency: CURRENCY
      }
    ).call
    created!(result, DEPARTURE_NAME)
  end
  private_class_method :create_departure!

  def self.created!(result, name)
    return result.record if result.status == :created && result.record

    raise "The Alpha fixture could not create #{name} (#{result.status})."
  end
  private_class_method :created!
end
