# Starts a supplier request for a booking's units from one arrangement
# (INV-33, SUP-10). Arrangement work (step 7 plan, question 7).
class BookingSupplierReservationsController < ApplicationController
  include BookingAccess

  before_action -> { require_permission!(:manage_supplier_reservations) }
  before_action :set_booking

  def create
    arrangement = Current.agency.supplier_arrangements.find(params[:arrangement_id])
    run_booking_command("supplier-requests", "Supplier request started. Record the supplier's answer on the arrangement when it comes.", step: params[:step].presence_in(BookingProgress::STEPS) || "rooms") do
      RequestSupplierReservation.new(agency: Current.agency, actor: Current.agency_user, booking: @booking, arrangement:,
        selection_ids: Array(params[:selection_ids])).call
    end
  end
end
