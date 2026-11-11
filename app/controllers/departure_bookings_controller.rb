# S-25: every booking on the Departure, with its owner, status, cabin,
# travelers, subtotal and hold (BKG-06, D-80), and starting a new one for a
# client found in the directory or created here.
class DepartureBookingsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action -> { require_permission!(:view_bookings) }
  before_action -> { require_permission!(:manage_bookings) }, only: %i[new create]
  before_action :set_departure

  def index
    @bookings = Current.agency.client_bookings.joins(:client_trip).where(client_trips: { departure_id: @departure.id })
      .includes(:price_lines, :inventory_allocations, :owner_reseller, { offering: :choices }, booking_travelers: :traveler,
        choice_selections: [ { supplier_reservation_units: :supplier_reservation }, { option: [ :choice, { inventory_group: :supplier_arrangement } ] } ],
        client_trip: { client: %i[client_person client_organization] })
      .order("client_trips.trip_reference", :sequence)
  end

  def new
    @query = params[:q].to_s.strip
    @clients = search_clients(@query)
    @person = {}
  end

  def create
    result = StartClientBooking.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, **start_params).call
    booking = result.record
    redirect_to client_booking_path(booking, step: "travelers"), notice: "Booking #{booking.booking_reference} started on trip #{booking.client_trip.trip_reference}."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    render_new_with(error.message)
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    render_new_with(error.message)
  end

  private

  def start_params
    if params[:client_id].present?
      { client: Current.agency.clients.find(params[:client_id]) }
    else
      person = params.fetch(:client_person, {}).permit(:first_name, :last_name, :traveling, :date_of_birth)
      { person: person.slice(:first_name, :last_name).to_h, traveling: person[:traveling] == "1", date_of_birth: person[:date_of_birth],
        acknowledgement_token: params[:acknowledgement_token], acknowledgement_reason: params[:acknowledgement_reason] }
    end
  end

  def render_new_with(message)
    @query = params[:q].to_s.strip
    @clients = search_clients(@query)
    @person = params.fetch(:client_person, {}).permit(:first_name, :last_name, :traveling, :date_of_birth).to_h
    @error = message
    render :new, status: :unprocessable_entity
  end

  # Active clients matching the search, people and organizations, with
  # their trips on this Departure.
  def search_clients(query)
    return [] if query.length < 2

    references = SearchClientDirectory.call(agency: Current.agency, actor: Current.agency_user, query:, status: "active", kind: "all")
      .records.filter_map(&:client_reference)
    Current.agency.clients.where(client_reference: references, status: "active")
      .includes(:client_person, :client_organization, :travelers, :client_trips).sort_by { |client| references.index(client.client_reference) }
  end
end
