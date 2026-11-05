class DepartureDecisionsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure

  def create
    RecordDepartureDecision.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      decision: params.dig(:departure_decision, :decision),
      note: params.dig(:departure_decision, :note),
      lock_version: params.dig(:departure_decision, :lock_version)
    ).call
    redirect_to departure_path(@departure, anchor: "decision"), notice: "Decision recorded."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_path(@departure, anchor: "decision"), alert: error.message
  end
end
