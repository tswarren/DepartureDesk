class DepartureReturnToDraftsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def edit
  end

  def create
    ReturnDepartureToDraft.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      reason: departure_params[:reason],
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure returned to draft."
  rescue AgencyCommand::Error => error
    @departure.define_singleton_method(:reason) { departure_params[:reason] } unless @departure.respond_to?(:reason)
    @reason = departure_params[:reason]
    rescue_departure_error(error, :edit)
  end
end
