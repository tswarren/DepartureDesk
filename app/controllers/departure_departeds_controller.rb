class DepartureDepartedsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_management!
  before_action :set_departure

  def new
  end

  def create
    MarkDepartureDeparted.new(
      agency: Current.agency,
      departure: @departure,
      actor_kind: :agency_user,
      actor: Current.agency_user,
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure marked departed."
  rescue AgencyCommand::Error => error
    rescue_departure_error(error, :new)
  end
end
