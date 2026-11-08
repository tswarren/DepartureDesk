# Adds someone not yet among the client's travelers to a draft booking from
# its travelers step: a new traveler profile, or an existing one found in
# the agency, linked to the responsible client with a relationship
# (CLT-05, CLT-09, CLT-10), then added with the type staff choose (CLT-13,
# BKG-21), or put in a placeholder's place, keeping its order, units and
# type unless another is chosen (CLT-15). One transaction through the
# commands that own each record.
class AddTravelerToBooking < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, booking:, relationship:, traveler_type_id: nil, traveler: nil, attributes: {}, replacing: nil)
    @agency = agency
    @actor = actor
    @booking = booking
    @relationship = relationship
    @traveler_type_id = traveler_type_id.presence
    @traveler = traveler
    @attributes = attributes.to_h
    @replacing = replacing
  end

  def call
    ensure_actor!

    raise Error.new("Only a placeholder can be replaced.", code: :invalid) if @replacing&.traveler_id

    ActiveRecord::Base.transaction do
      client = @booking.client_trip.client
      traveler = if @traveler
        LinkTraveler.new(agency: @agency, actor: @actor, client:, traveler_id: @traveler.id, relationship: @relationship).call unless client.traveler_links.exists?(traveler: @traveler)
        @traveler
      else
        SaveTraveler.new(agency: @agency, actor: @actor, attributes: @attributes, link_client: client, relationship: @relationship.presence_in(TravelerLink::RELATIONSHIPS) || "other").call.record
      end
      row = SaveBookingTraveler.new(agency: @agency, actor: @actor, booking: @booking, booking_traveler: @replacing,
        attributes: { traveler_id: traveler.id, traveler_type_id: @traveler_type_id }.compact).call.record
      Result.new(status: :created, record: row)
    end
  end
end
