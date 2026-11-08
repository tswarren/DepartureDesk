# Travelers on a draft booking (CLT-13, CLT-15).
class BookingTravelersController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    run_booking_command("travelers", "Traveler added.") do
      SaveBookingTraveler.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, attributes: traveler_params).call
    end
  end

  def update
    record = @booking.booking_travelers.find(params[:id])
    notice = record.placeholder_label && traveler_params["traveler_id"].present? ? "#{record.placeholder_label} replaced." : "Traveler updated."
    run_booking_command("travelers", notice) do
      SaveBookingTraveler.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, booking_traveler: record,
        attributes: traveler_params, lock_version: params.dig(:booking_traveler, :lock_version)).call
    end
  end

  def destroy
    record = @booking.booking_travelers.find(params[:id])
    run_booking_command("travelers", "Traveler removed from the booking.") do
      RemoveBookingTraveler.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, booking_traveler: record).call
    end
  end

  private

  def traveler_params
    params.fetch(:booking_traveler, {}).permit(:traveler_id, :placeholder_label, :traveler_type_id, :position).to_h
  end
end
