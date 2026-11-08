# Confirm (BKG-45). A refusal lists what is missing, each linked to where
# it is fixed (D16).
class BookingConfirmationsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    ConfirmClientBooking.new(agency: Current.agency, actor: Current.agency_user, booking: @booking).call
    redirect_to booking_step_path(@booking, "confirm"), notice: "Booking confirmed."
  rescue ConfirmClientBooking::Blocked => error
    redirect_to booking_step_path(@booking, "form-error-summary"),
      flash: { blockers: error.blockers.map { |blocker| [ blocker.message, blocker.anchor ] } }
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to booking_step_path(@booking, "confirm"), alert: error.message
  end
end
