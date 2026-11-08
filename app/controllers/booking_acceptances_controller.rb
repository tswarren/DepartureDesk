# S-27: record the client's acceptance of a draft booking's current price
# and terms (BKG-39, BKG-41), with optional evidence (ADR 0019 amendment).
class BookingAcceptancesController < ApplicationController
  include BookingAccess
  include TripAccess

  FIELD_LABELS = [ [ :accepted_by, "Accepted by" ], [ :acceptance_method, "Method" ], [ :accepted_on, "Date accepted" ],
                   [ :note, "Note" ], [ :evidence_reference, "Evidence" ], [ :payment_amount, "Payment amount" ],
                   [ :payment_on, "Payment date" ], [ :payment_reference, "Payment reference" ] ].freeze

  before_action :set_booking

  def new
    unless @booking.status_draft? && @booking.price_lines.any?
      return redirect_to booking_step_path(@booking, "acceptance"),
        alert: @booking.status_draft? ? "Choose options and place travelers first; there is no price to accept yet." : "Only a draft booking takes a new acceptance."
    end

    @acceptance = @booking.acceptances.new(accepted_by: @booking.client_trip.client.source.display_name,
      accepted_on: Clock.current.today_in(Current.agency.default_timezone), acceptance_method: "email")
  end

  def create
    RecordBookingAcceptance.new(agency: Current.agency, actor: Current.agency_user, booking: @booking,
      attributes: acceptance_params, evidence: params.dig(:booking_acceptance, :evidence)).call
    redirect_to booking_step_path(@booking, "acceptance"), notice: "Acceptance recorded."
  rescue AgencyCommand::Error => error
    @acceptance = @booking.acceptances.new(acceptance_params.slice("accepted_by", "acceptance_method", "note", "evidence_reference", "payment_reference"))
    @acceptance.accepted_on = acceptance_params["accepted_on"]
    @payment = acceptance_params.slice("payment_on", "payment_amount")
    render_form_error(error, @acceptance, :new, FIELD_LABELS)
  end

  private

  def acceptance_params
    params.fetch(:booking_acceptance, {}).permit(*RecordBookingAcceptance::FIELDS).to_h
  end
end
