# Adjusts a draft booking's proposed installments before acceptance (CMN-09).
class InstallmentProposalsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def update
    ids = @booking.installment_proposals.map(&:id)
    rows = params.fetch(:proposals, {}).permit(ids.to_h { |id| [ id, %i[amount due due_on] ] }).to_h.map { |id, row| row.merge("id" => id) }
    run_booking_command("installments", "Installments adjusted. Record the client's acceptance again if it was recorded.", step: "price") do
      AdjustInstallmentProposals.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, rows:).call
    end
  end
end
