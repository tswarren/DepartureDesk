class DepartureScheduleCorrectionsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def edit
    @reason = nil
  end

  def create
    CorrectDepartureSchedule.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      starts_on: departure_params[:starts_on],
      ends_on: departure_params[:ends_on],
      time_zone: departure_params[:time_zone],
      reason: departure_params[:reason],
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure schedule corrected."
  rescue AgencyCommand::Error => error
    assign_submitted_departure_fields
    @reason = departure_params[:reason]
    rescue_departure_error(error, :edit)
  end
end
