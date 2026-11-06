class SupplierArrangementDiscardsController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def create
    DiscardSupplierArrangement.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement,
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_arrangements_path(@departure), notice: "Arrangement discarded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_path(@departure, @arrangement), alert: error.message
  end
end
