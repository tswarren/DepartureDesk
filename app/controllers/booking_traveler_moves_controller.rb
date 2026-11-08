# Moves a traveler up or down a draft booking's order (CLT-13).
class BookingTravelerMovesController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    record = @booking.booking_travelers.find(params[:traveler_id])
    run_booking_command("travelers", "Order updated.") do
      MoveBookingTraveler.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, booking_traveler: record, direction: params[:direction]).call
    end
  end
end
