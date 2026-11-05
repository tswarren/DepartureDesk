class DepartureReadyToSellsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure

  def show
    @ready_to_sell_blockers = @departure.ready_to_sell_blockers
  end

  def create
    MarkDepartureReadyToSell.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure is Ready to sell."
  rescue AgencyCommand::Error => error
    @ready_to_sell_blockers = @departure.ready_to_sell_blockers
    rescue_departure_error(error, :show)
  end
end
