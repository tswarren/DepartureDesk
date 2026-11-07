# Hold space, extend the hold once, or release it (BKG-09 to BKG-11).
class BookingHoldsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def create
    run_booking_command("hold", "Space held.") do
      HoldBookingSpace.new(agency: Current.agency, actor: Current.agency_user, booking: @booking).call
    end
  end

  def update
    run_booking_command("hold", "Hold extended.") do
      ExtendBookingHold.new(agency: Current.agency, actor: Current.agency_user, booking: @booking).call
    end
  end

  def destroy
    selection = params[:selection_id].present? ? @booking.choice_selections.find(params[:selection_id]) : nil
    run_booking_command("hold", "Held space released.") do
      ReleaseBookingHold.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, selection:).call
    end
  end
end
