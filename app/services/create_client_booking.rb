# Creates a Draft booking on a Client Trip for its Departure's package
# (BKG-05, BKG-06), referenced from the trip (REF-04, SC-REF-06). The
# Departure must be On sale (DEP-05; step 6 plan, question 7). Once
# created, the booking saves with details missing (D16).
#
# A reseller user books only on an offering published to its relationship,
# for a trip on its own bookings or a client its users created, and the
# booking is then owned by that relationship with it as seller of record
# (D-99 (1), ACC-18, FIN-05, CLT-25).
class CreateClientBooking < AgencyCommand
  include BookingCommandSupport
  allow_reseller_actor

  def initialize(agency:, actor:, trip:)
    @agency = agency
    @actor = actor
    @trip = trip
  end

  def call
    ensure_actor!

    ActiveRecord::Base.transaction do
      @agency.lock!
      trip = @agency.client_trips.lock.find(@trip.id)
      raise Error.new("Link the trip to a Departure before booking its package.", code: :invalid_state) if trip.departure_id.nil?

      departure = @agency.departures.lock.find(trip.departure_id)
      ensure_on_sale!(departure, "it can't take a new booking")
      offering = departure.offerings.first
      raise Error.new("#{departure.name} has no package to book.", code: :invalid_state) if offering.nil?

      ensure_reseller_trip!(trip)
      ensure_published_to_reseller!(offering, "it can't be booked")
      sequence = trip.client_bookings.maximum(:sequence).to_i + 1
      booking = trip.client_bookings.create!(
        agency: @agency, offering:, sequence:, booking_reference: "#{trip.trip_reference}-#{sequence}",
        created_by: @actor, client_terms_version: departure.current_client_terms, **reseller_parties
      )
      audit_booking!(booking, "client_booking.created", { "client_trip_id" => trip.id, "offering_id" => offering.id }.merge(reseller_parties.transform_keys(&:to_s)))
      Result.new(status: :created, record: booking)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end

  private

  def reseller_parties
    return {} unless reseller_actor?

    { owner_kind: "reseller", owner_reseller_id: @actor.reseller_id, seller_kind: "reseller", seller_reseller_id: @actor.reseller_id }
  end

  def ensure_reseller_trip!(trip)
    return unless reseller_actor?

    scope = ResellerScope.new(@actor)
    return if scope.trips.exists?(id: trip.id) || scope.clients.exists?(id: trip.client_id)

    raise ActiveRecord::RecordNotFound.new("Couldn't find ClientTrip", "ClientTrip")
  end
end
