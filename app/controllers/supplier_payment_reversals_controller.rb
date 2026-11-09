# Reverses a supplier payment with a reason (SMN-23).
class SupplierPaymentReversalsController < ApplicationController
  include SupplierPaymentAccess

  before_action :set_payment

  def new
  end

  def create
    ReverseSupplierPayment.new(agency: Current.agency, actor: Current.agency_user, payment: @payment, reason: params[:reason], reversed_on: params[:reversed_on]).call
    money_tab(notice: "#{@payment.payment_reference} reversed; the amounts it paid are open again.")
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def set_payment
    @payment = @departure.supplier_payments.find(params[:supplier_payment_id])
  end
end
