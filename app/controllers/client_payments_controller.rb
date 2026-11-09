# S-29: record a client payment on a trip, applied oldest first by default (CMN-18, CMN-21, CMN-29).
class ClientPaymentsController < ApplicationController
  include ClientMoneyAccess
  include TripAccess

  before_action :set_trip

  def new
    @booking = return_booking
    @money = TripMoney.new(@trip)
    @values = { "payer_client_id" => @trip.client_id, "paid_on" => Clock.current.today_in(Current.agency.default_timezone).iso8601, "route" => "agency", "payment_method" => "check" }
  end

  def create
    result = RecordClientPayment.new(agency: Current.agency, actor: Current.agency_user, trip: @trip, attributes: payment_params, applications: application_rows).call
    payment = result.record
    notice = "#{payment.payment_reference} recorded#{", receipt #{payment.receipt.receipt_number} issued" if payment.receipt}."
    booking = return_booking
    return redirect_to(client_booking_path(booking, step: params[:step].presence_in(BookingProgress::STEPS) || "price", anchor: "booking-money"), notice:) if booking

    money_redirect(notice:)
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @booking = return_booking
    @money = TripMoney.new(@trip)
    @values = payment_params
    @applied = application_rows.to_h { |row| [ row[:installment_id], row[:amount] ] }
    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def payment_params = params.fetch(:client_payment, {}).permit(*RecordClientPayment::FIELDS).to_h

  # Opened from a booking: back to it once recorded.
  def return_booking = params[:booking_id].present? ? @trip.client_bookings.find_by(id: params[:booking_id]) : nil

  def application_rows
    ids = TripMoney.new(@trip).open_installments.map(&:id)
    params.fetch(:applications, {}).permit(*ids).to_h.map { |installment_id, amount| { installment_id:, amount: } }
  end
end
