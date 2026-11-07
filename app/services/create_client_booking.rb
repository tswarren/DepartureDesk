# Creates a Draft booking on a Client Trip for its Departure's package
# (BKG-05, BKG-06), referenced from the trip (REF-04, SC-REF-06). The
# Departure must be On sale (DEP-05; step 6 plan, question 7). Once
# created, the booking saves with details missing (D16).
class CreateClientBooking < AgencyCommand
  include BookingCommandSupport

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

      sequence = trip.client_bookings.maximum(:sequence).to_i + 1
      booking = trip.client_bookings.create!(
        agency: @agency, offering:, sequence:, booking_reference: "#{trip.trip_reference}-#{sequence}",
        created_by: @actor, client_terms_version: departure.current_client_terms
      )
      audit_booking!(booking, "client_booking.created", "client_trip_id" => trip.id, "offering_id" => offering.id)
      Result.new(status: :created, record: booking)
    end
  rescue ActiveRecord::RecordInvalid => error
    raise Error.new(error.record.errors.full_messages.to_sentence, code: :invalid)
  end
end
