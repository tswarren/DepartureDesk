# Applies a trip's credit to its installments (CMN-23, CMN-24).
class ClientCreditApplicationsController < ApplicationController
  include ClientMoneyAccess

  before_action :set_trip

  def create
    ids = TripMoney.new(@trip).open_installments.map(&:id)
    rows = params.fetch(:applications, {}).permit(*ids).to_h.map { |installment_id, amount| { installment_id:, amount: } }
    ApplyClientCredit.new(agency: Current.agency, actor: Current.agency_user, trip: @trip, applications: rows).call
    money_redirect(notice: "Credit applied.")
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    money_redirect(alert: error.message)
  end
end
