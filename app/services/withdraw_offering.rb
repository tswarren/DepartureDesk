# Withdraws an offering from one reseller's channel (DEP-09). Bookings the
# reseller already owns keep their state; it can no longer start or hold new
# ones on the offering. ReturnDepartureToDraft withdraws every open
# publication itself (DEP-08), through .withdraw_all!.
class WithdrawOffering < AgencyCommand
  include DepartureCommandSupport

  def self.withdraw_all!(departure, actor)
    publications = OfferingPublication.open.where(offering_id: departure.offerings.select(:id)).order(:id).lock.to_a
    now = Clock.current.now
    publications.each { |publication| publication.update!(withdrawn_at: now, withdrawn_by: actor) }
    publications
  end

  def initialize(agency:, actor:, publication:)
    @agency = agency
    @actor = actor
    @publication = publication
  end

  def call
    ensure_departure_actor!(:publish_offerings)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:publish_offerings)
      departure = @agency.departures.lock.find(@publication.offering.departure_id)
      publication = OfferingPublication.where(agency: @agency).lock.find(@publication.id)
      return Result.new(status: :noop, record: publication) unless publication.open?

      publication.update!(withdrawn_at: Clock.current.now, withdrawn_by: @actor)
      audit!(agency: @agency, action: "departure.offering_withdrawn", subject: departure, actor: @actor,
        details: { "departure_id" => departure.id, "offering_id" => publication.offering_id, "reseller_id" => publication.reseller_id,
                   "offering_publication_ids" => [ publication.id ] })
      Result.new(status: :updated, record: publication)
    end
  end
end
