# S-26: the booking workspace, and creating a draft booking from its trip.
class ClientBookingsController < ApplicationController
  include BookingAccess
  include TripAccess

  before_action :set_booking, only: :show

  def show
    @booking = Current.agency.client_bookings
      .includes(:offering, :created_by, :client_terms_version, client_trip: [ :departure, { client: %i[client_person client_organization] } ],
        booking_travelers: %i[traveler traveler_type],
        choice_selections: [ :occupants, { option: [ :choice, :inventory_group ] } ],
        inventory_allocations: %i[inventory_group unit_shell choice_selection],
        price_lines: [ :booking_traveler, { choice_selection: { option: :choice } } ],
        acceptances: [ :recorded_by, :client_terms_version, { evidence_attachment: :blob } ], cost_lines: :schedule_lines,
        expected_commissions: [ :overridden_by, { choice_selection: { option: :choice } } ])
      .find(@booking.id)
    @trip = @booking.client_trip
    @choices = @booking.offering.choices.includes(options: :inventory_group)
    @blockers = BookingConfirmationCheck.new(@booking).blockers
    @linked_travelers = @trip.client.travelers.ordered.reject { |traveler| @booking.booking_travelers.any? { |row| row.traveler_id == traveler.id } }
    @traveler_types = Current.agency.traveler_types.active.ordered
    @blocked = flash[:blockers]
    @progress = BookingProgress.new(@booking, @blockers)
    @step = params[:step].presence_in(BookingProgress::STEPS) || @progress.current
  end

  def create
    trip = Current.agency.client_trips.find(params[:client_trip_id])
    result = CreateClientBooking.new(agency: Current.agency, actor: Current.agency_user, trip:).call
    redirect_to client_booking_path(result.record), notice: "Booking #{result.record.booking_reference} created as a draft."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to client_trip_path(trip), alert: error.message
  end
end
