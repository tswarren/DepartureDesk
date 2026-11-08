# Adds the ticked travelers to a draft booking, each with its chosen type (CLT-13, BKG-21).
class BookingTravelerBatchesController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    ids = @booking.client_trip.client.travelers.ids
    submitted = params.fetch(:travelers, {}).permit(ids.to_h { |id| [ id, %i[add traveler_type_id] ] }).to_h
    rows = submitted.filter_map { |id, row| { "traveler_id" => id, "traveler_type_id" => row["traveler_type_id"] } if row["add"] == "1" }
    run_booking_command("travelers", "#{rows.size == 1 ? "Traveler" : "Travelers"} added.") do
      AddBookingTravelers.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, rows:).call
    end
  end
end
