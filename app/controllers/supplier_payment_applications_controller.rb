# Applies a supplier's unapplied payments to its amounts due (SMN-19, SMN-22).
class SupplierPaymentApplicationsController < ApplicationController
  include SupplierPaymentAccess

  before_action :set_supplier

  def create
    ids = AmountDue.where(supplier_arrangement: @departure.supplier_arrangements.live.where(supplier: @supplier)).pluck(:id)
    rows = params.fetch(:applications, {}).permit(*ids).to_h.map { |amount_due_id, amount| { amount_due_id:, amount: } }
    ApplySupplierPayment.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, supplier: @supplier, applications: rows).call
    money_tab(notice: "Unapplied payment applied.")
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    money_tab(alert: error.message)
  end
end
