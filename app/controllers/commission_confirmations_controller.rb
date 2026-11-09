# Records the supplier's confirmation of an expected commission (SMN-33, D-96 (4)).
class CommissionConfirmationsController < ApplicationController
  include BookingAccess

  before_action -> { require_permission!(:confirm_commission) }
  before_action :set_booking

  def create
    commission = @booking.expected_commissions.find(params[:commission_id])
    run_booking_command("supplier-cost", "Commission confirmed.", step: "confirm") do
      ConfirmExpectedCommission.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, commission:, amount: params[:amount]).call
    end
  end
end
