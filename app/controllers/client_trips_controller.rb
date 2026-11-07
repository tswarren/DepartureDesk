# S-24 Client Trip: one responsible client (CLT-02), at most one Departure
# (OVR-02), its reference and its derived status (BKG-03).
class ClientTripsController < ApplicationController
  include TripAccess

  before_action -> { require_permission!(:view_bookings) }
  before_action -> { require_permission!(:manage_bookings) }, except: :show
  before_action :set_trip, only: %i[show edit update]

  def show
    @travelers = @trip.client.travelers.includes(:links).ordered
  end

  def new
    @client = Current.agency.clients.find(params[:client_id])
    @trip = Current.agency.client_trips.new(client: @client, departure_id: params[:departure_id])
  end

  def create
    @client = Current.agency.clients.find(params.dig(:client_trip, :client_id))
    result = SaveClientTrip.new(agency: Current.agency, actor: Current.agency_user, attributes: trip_params).call
    redirect_to client_trip_path(result.record), notice: "Trip #{result.record.trip_reference} created."
  rescue AgencyCommand::Error => error
    @trip = Current.agency.client_trips.new(client: @client)
    render_form_error(error, @trip, :new, [ [ :departure_id, "Departure" ], [ :client_id, "Client" ] ])
  end

  def edit
  end

  def update
    SaveClientTrip.new(agency: Current.agency, actor: Current.agency_user, trip: @trip, attributes: trip_params,
      lock_version: params.dig(:client_trip, :lock_version)).call
    redirect_to client_trip_path(@trip), notice: "Trip updated."
  rescue AgencyCommand::Error => error
    render_form_error(error, @trip, :edit, [ [ :departure_id, "Departure" ] ])
  end

  private

  def set_trip
    @trip = Current.agency.client_trips.includes(:departure, client: %i[client_person client_organization]).find(params[:id])
  end

  def trip_params = form_params(:client_trip, %i[client_id departure_id])

  def departure_options
    Current.agency.departures.where(completion_status: "active").order(:starts_on, :name).map { |departure| [ "#{departure.departure_reference} · #{departure.name}", departure.id ] }
  end
  helper_method :departure_options
end
