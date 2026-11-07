# Discards a draft booking, releasing its holds (BKG-06).
class BookingDiscardsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    run_booking_command("status", "Booking discarded. Its held space is released.") do
      DiscardClientBooking.new(agency: Current.agency, actor: Current.agency_user, booking: @booking).call
    end
  end
end
