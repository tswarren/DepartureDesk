# Assigns a booking to a reseller or to agency ownership (ACC-18; step 9
# plan question 6). Needs Departure management; the seller of record stays.
class BookingAssignmentsController < ApplicationController
  include BookingAccess

  before_action -> { require_permission!(:assign_bookings) }
  before_action :set_booking

  def update
    reseller = params[:reseller_id].presence && Current.agency.resellers.find(params[:reseller_id])
    run_booking_command("summary-sales", reseller ? "Booking assigned to #{reseller.name}." : "Booking assigned to the agency.", step: "summary") do
      AssignClientBooking.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, reseller:, lock_version: params[:lock_version]).call
    end
  end
end
