class DepartureCurrencyCorrectionsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def edit
    @reason = nil
  end

  def create
    CorrectDepartureCurrency.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      operating_currency: departure_params[:operating_currency],
      reason: departure_params[:reason],
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure currency corrected."
  rescue AgencyCommand::Error => error
    assign_submitted_departure_fields
    @reason = departure_params[:reason]
    rescue_departure_error(error, :edit)
  end
end
