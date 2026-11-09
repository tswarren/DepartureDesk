# Reverses a client payment with a reason (CMN-27, D-96 (1)).
class ClientPaymentReversalsController < ApplicationController
  include ClientMoneyAccess
  include TripAccess

  before_action :set_trip
  before_action :set_payment

  def new
  end

  def create
    ReverseClientPayment.new(agency: Current.agency, actor: Current.agency_user, payment: @payment, reason: params[:reason], reversed_on: params[:reversed_on]).call
    money_redirect(notice: "#{@payment.payment_reference} reversed; the installments it paid are open again.")
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_payment
    @payment = @trip.client_payments.find(params[:payment_id])
  end
end
