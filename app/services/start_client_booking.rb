# Starts a booking from the Departure's Bookings tab (S-25): for a client
# found in the directory, or a new person made a client there, with the
# booking on that client's trip for this Departure, or a new trip (CLT-02,
# OVR-02). A new client who is also traveling gets a traveler profile
# linked as Self and is added to the booking (CLT-05, CLT-09, CLT-13). All
# of it happens in one transaction through the commands that own each
# record, so a refusal leaves nothing behind.
class StartClientBooking < AgencyCommand
  include BookingCommandSupport

  def initialize(agency:, actor:, departure:, client: nil, person: nil, traveling: false, date_of_birth: nil,
    acknowledgement_token: nil, acknowledgement_reason: nil)
    @agency = agency
    @actor = actor
    @departure = departure
    @client = client
    @person = person.to_h.symbolize_keys.slice(:first_name, :last_name)
    @traveling = traveling
    @date_of_birth = date_of_birth.presence
    @acknowledgement_token = acknowledgement_token
    @acknowledgement_reason = acknowledgement_reason
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      ensure_on_sale!(@agency.departures.find(@departure.id), "it can't take a new booking")
      client = @client || new_client!
      trip = existing_trip(client) || SaveClientTrip.new(agency: @agency, actor: @actor,
        attributes: { client_id: client.id, departure_id: @departure.id }).call.record
      booking = CreateClientBooking.new(agency: @agency, actor: @actor, trip:).call.record
      if (traveler = @new_traveler)
        SaveBookingTraveler.new(agency: @agency, actor: @actor, booking:, attributes: { traveler_id: traveler.id }).call
      end
      Result.new(status: :created, record: booking)
    end
  end

  private

  # The client's most recent trip on this Departure, if any.
  def existing_trip(client)
    @agency.client_trips.where(client:, departure: @departure).order(created_at: :desc).first
  end

  def new_client!
    raise Error.new("First name and last name are required.", code: :invalid) if @person.values_at(:first_name, :last_name).any?(&:blank?)

    person = CreateClientPerson.new(agency: @agency, actor: @actor, names: @person,
      acknowledgement_token: @acknowledgement_token, acknowledgement_reason: @acknowledgement_reason).call.record
    client = person.client || CreateClientForPerson.new(agency: @agency, actor: @actor, client_person: person).call.record
    if @traveling
      @new_traveler = SaveTraveler.new(agency: @agency, actor: @actor, link_client: client, relationship: "self",
        attributes: { given_names: @person[:first_name], surname: @person[:last_name], date_of_birth: @date_of_birth }.compact).call.record
    end
    client
  end
end
