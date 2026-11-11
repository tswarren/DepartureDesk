# A reseller user starts a booking on an offer published to its
# relationship (D-99 (1), ACC-15, CLT-25): a new person made a client, a
# Client Trip on the offer's Departure, and a Draft booking owned by the
# relationship with it as seller of record. A client who is also traveling
# gets a traveler profile linked as Self and is added to the booking
# (CLT-05, CLT-09, CLT-11, CLT-13). The reseller never searches the
# agency's directory, so the client is always new, with no duplicate check
# (D-78). One transaction through the commands that own each record.
class StartResellerBooking < AgencyCommand
  def initialize(agency:, actor:, offering:, person:, traveling: false, date_of_birth: nil)
    @agency = agency
    @actor = actor
    @offering = offering
    @person = person.to_h.symbolize_keys.slice(:first_name, :last_name).transform_values { |value| value.to_s.strip.presence }
    @traveling = ActiveModel::Type::Boolean.new.cast(traveling)
    @date_of_birth = date_of_birth.presence
  end

  def call
    raise Error.new(UNAUTHORIZED, code: :unauthorized) unless reseller_actor?

    ensure_reseller_actor!(:reseller_manage_bookings)
    ensure_active_agency!(@agency)
    offering = ResellerScope.new(@actor).offerings.find(@offering.id)
    raise Error.new("First name and last name are required.", code: :invalid) if @person.values_at(:first_name, :last_name).any?(&:blank?)

    ActiveRecord::Base.transaction do
      client = CreateIndividualClient.new(agency: @agency, actor: @actor, names: @person, for_reseller_booking: true).call.record
      trip = SaveClientTrip.new(agency: @agency, actor: @actor, attributes: { client_id: client.id, departure_id: offering.departure_id }).call.record
      booking = CreateClientBooking.new(agency: @agency, actor: @actor, trip:).call.record
      if @traveling
        traveler = SaveTraveler.new(agency: @agency, actor: @actor, link_client: client, relationship: "self", reseller_booking: booking,
          attributes: { given_names: @person[:first_name], surname: @person[:last_name], date_of_birth: @date_of_birth }.compact).call.record
        SaveBookingTraveler.new(agency: @agency, actor: @actor, booking:, attributes: { traveler_id: traveler.id }).call
      end
      Result.new(status: :created, record: booking)
    end
  end
end
