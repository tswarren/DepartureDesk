# Records a draft booking's seller of record (FIN-05, seller of record only;
# step 9 plan question 6). Needs Departure management.
class BookingSellersController < ApplicationController
  include BookingAccess

  before_action -> { require_permission!(:assign_bookings) }
  before_action :set_booking

  def update
    reseller = params[:reseller_id].presence && Current.agency.resellers.find(params[:reseller_id])
    run_booking_command("summary-sales", "Seller of record set to #{reseller&.name || "the agency"}.", step: "summary") do
      SetBookingSellerOfRecord.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, reseller:, lock_version: params[:lock_version]).call
    end
  end
end
