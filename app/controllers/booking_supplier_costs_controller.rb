# Overrides a confirmed booking's proposed supplier cost or expected
# commission (SUP-35, SMN-32). Needs Supplier arrangements or Financial records.
class BookingSupplierCostsController < ApplicationController
  include BookingAccess

  before_action :set_booking

  def update
    record = params[:record] == "commission" ? { commission: @booking.expected_commissions.find(params[:id]) } : { cost_line: @booking.cost_lines.find(params[:id]) }
    run_booking_command("supplier-cost", "Supplier cost updated.") do
      OverrideBookingSupplierCost.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, amount: params[:amount], **record).call
    end
  end
end
