class DepartureLifecycleCorrectionsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def edit
    @reason = nil
  end

  def create
    CorrectDepartureLifecycle.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      reason: departure_params[:reason],
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure returned to active."
  rescue AgencyCommand::Error => error
    @reason = departure_params[:reason]
    rescue_departure_error(error, :edit)
  end
end
