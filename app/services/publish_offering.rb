# Publishes an offering to one reseller's channel (DEP-07; D-68, one channel
# per relationship). Only a Ready to sell Departure can be published; open
# review items don't block it (DEP-09). Publishing again after a withdrawal
# makes a new publication.
class PublishOffering < AgencyCommand
  include DepartureCommandSupport

  def initialize(agency:, actor:, offering:, reseller:)
    @agency = agency
    @actor = actor
    @offering = offering
    @reseller = reseller
  end

  def call
    ensure_departure_actor!(:publish_offerings)

    ActiveRecord::Base.transaction do
      lock_authorized_agency!(:publish_offerings)
      @departure = @agency.departures.lock.find(@offering.departure_id)
      offering = @departure.offerings.lock.find(@offering.id)
      reseller = @agency.resellers.lock.find(@reseller.id)
      if @departure.departed?
        raise Error.new("#{@departure.name} has departed, so its packages can't be published.", code: :invalid_state)
      end
      unless @departure.ready_to_sell?
        raise Error.new("#{@departure.name} is a draft. Mark it Ready to sell before publishing its package.", code: :invalid_state)
      end
      raise Error.new("#{reseller.name} is #{reseller.status_label.downcase}, so nothing can be published to it.", code: :invalid_state) unless reseller.active?
      if offering.publications.open.exists?(reseller_id: reseller.id)
        raise Error.new("#{offering.name} is already published to #{reseller.name}.", code: :invalid_state)
      end

      publication = offering.publications.create!(agency: @agency, reseller:, published_at: Clock.current.now, published_by: @actor)
      audit!(agency: @agency, action: "departure.offering_published", subject: @departure, actor: @actor,
        details: { "departure_id" => @departure.id, "offering_id" => offering.id, "reseller_id" => reseller.id, "offering_publication_id" => publication.id })
      Result.new(status: :created, record: publication)
    end
  rescue ActiveRecord::RecordNotUnique
    raise Error.new("#{@offering.name} is already published to #{@reseller.name}.", code: :invalid_state)
  end
end
