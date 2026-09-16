class DepartureResponsibilitiesController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def edit
  end

  def update
    UpdateDepartureResponsibility.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      office_id: departure_params[:responsible_office_id],
      agency_user_id: departure_params[:responsible_agency_user_id],
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Responsibility updated."
  rescue AgencyCommand::Error => error
    assign_submitted_departure_fields
    rescue_departure_error(error, :edit)
  end
end
