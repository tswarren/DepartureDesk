# S-31: record a payment to one supplier, applied to its amounts due oldest first by default (SMN-18, SMN-19).
class SupplierPaymentsController < ApplicationController
  include SupplierPaymentAccess

  before_action :set_supplier

  def new
    @open = open_amounts
    @values = { "paid_on" => Clock.current.today_in(Current.agency.default_timezone).iso8601, "payment_method" => "bank_transfer",
                "payee_account_id" => @departure.supplier_arrangements.live.find_by(supplier: @supplier)&.payee_account_id }
  end

  def create
    payment = RecordSupplierPayment.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, supplier: @supplier,
      attributes: payment_params, applications: application_rows).call.record
    money_tab(notice: "#{payment.payment_reference} recorded.")
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @open = open_amounts
    @values = payment_params
    @applied = application_rows.to_h { |row| [ row[:amount_due_id], row[:amount] ] }
    @error = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def open_amounts
    AmountDue.where(supplier_arrangement: @departure.supplier_arrangements.live.where(supplier: @supplier))
      .includes(:payment_applications, :schedule_line).by_due.to_a.select { |amount| amount.open_minor_units.positive? }
  end

  def payment_params = params.fetch(:supplier_payment, {}).permit(*RecordSupplierPayment::FIELDS).to_h

  def application_rows
    params.fetch(:applications, {}).permit(*open_amounts.map(&:id)).to_h.map { |amount_due_id, amount| { amount_due_id:, amount: } }
  end
end
