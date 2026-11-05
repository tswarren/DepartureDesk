class DeparturesController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: %i[index show]
  before_action :set_departure, only: %i[show edit update]
  before_action :refuse_departed_edit, only: %i[edit update]

  def index
    @status = params[:status].presence || "all"
    @search = SearchDepartures.call(
      agency: Current.agency,
      actor: Current.agency_user,
      query: params[:q],
      status: @status,
      team_member_id: params[:team_member_id],
      starts_on_from: params[:starts_on_from],
      starts_on_to: params[:starts_on_to],
      ends_on_from: params[:ends_on_from],
      ends_on_to: params[:ends_on_to]
    )
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @search = SearchDepartures::Outcome.new(records: [], truncated: false)
    flash.now[:alert] = error.message
    render :index, status: :unprocessable_entity
  end

  def show
  end

  def new
    defaults = CreateDeparture.proposed_attributes(
      agency: Current.agency,
      actor: Current.agency_user
    )
    @departure = departures_scope.new(defaults)
  end

  def create
    result = CreateDeparture.new(
      agency: Current.agency,
      actor: Current.agency_user,
      attributes: departure_params
    ).call
    redirect_to departure_path(result.record), notice: "Departure saved."
  rescue AgencyCommand::Error => error
    @departure = departures_scope.new
    assign_submitted_departure_fields
    rescue_departure_error(error, :new)
  end

  def edit
  end

  def update
    UpdateDeparture.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      attributes: departure_params,
      lock_version: departure_params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure updated."
  rescue AgencyCommand::Error => error
    assign_submitted_departure_fields
    rescue_departure_error(error, :edit)
  end

  private

  # DEP-43: a Departed Departure is read-only.
  def refuse_departed_edit
    return unless @departure.departed?

    redirect_to departure_path(@departure), alert: "A departed departure cannot be edited."
  end
end
