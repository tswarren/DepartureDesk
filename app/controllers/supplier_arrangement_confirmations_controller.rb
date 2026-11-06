class SupplierArrangementConfirmationsController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def show
    redirect_to departure_arrangement_path(@departure, @arrangement), alert: "Only a draft arrangement can be confirmed." unless @arrangement.draft?
  end

  def create
    ConfirmSupplierArrangement.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      confirmed_on: params[:confirmed_on], confirmation_note: params[:confirmation_note], lock_version: params[:lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @arrangement), notice: "Arrangement confirmed. Its shells and pools now exist."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @error = error.message
    render :show, status: :unprocessable_entity
  end
end
