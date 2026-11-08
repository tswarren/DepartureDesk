# Adds a new traveler, or one found in the agency, to a draft booking and
# links them to its client (CLT-05, CLT-09, CLT-13).
class BookingTravelerAdditionsController < ApplicationController
  include BookingAccess

  before_action -> { require_permission!(:manage_client_directory) }
  before_action :set_booking

  def create
    traveler = Current.agency.travelers.find(params[:traveler_id]) if params[:traveler_id].present?
    attributes = params.fetch(:traveler, {}).permit(:given_names, :surname, :date_of_birth).to_h
    run_booking_command("travelers", "Traveler added and linked to #{@booking.client_trip.client.source.display_name}.") do
      AddTravelerToBooking.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, traveler:, attributes:,
        relationship: params[:relationship], traveler_type_id: params[:traveler_type_id]).call
    end
  end
end
