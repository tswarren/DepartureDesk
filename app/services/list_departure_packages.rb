# frozen_string_literal: true

class ListDeparturePackages < AgencyCommand
  include PackageCommandSupport

  Outcome = Data.define(:records, :truncated)
  LIMIT = 50

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
    rows = departure.packages.includes(:versions).order(:name, :id).limit(LIMIT + 1).to_a
    Outcome.new(records: rows.first(LIMIT), truncated: rows.size > LIMIT)
  end
end
