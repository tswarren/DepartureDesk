# frozen_string_literal: true

class ListDepartureServiceOffers < AgencyCommand
  include OfferCommandSupport

  Outcome = Data.define(:records, :truncated)
  LIMIT = 50
  FETCH_LIMIT = LIMIT + 1

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(agency:, actor:, departure:)
    @agency = agency
    @actor = actor
    @departure = departure
  end

  def call
    ensure_directory_actor!(@actor, @agency, :manage_departures)
    departure = @agency.departures.find(@departure.id)
    rows = departure.service_offers
      .includes(versions: :definition)
      .order(:name, :id)
      .limit(FETCH_LIMIT)
      .to_a
    Outcome.new(records: rows.first(LIMIT), truncated: rows.size > LIMIT)
  end
end
