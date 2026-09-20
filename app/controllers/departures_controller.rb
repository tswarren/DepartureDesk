class DeparturesController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: %i[index show]
  before_action :set_departure, only: %i[show edit update activate]

  def index
    @status = params[:status].presence || "all"
    @search = SearchDepartures.call(
      agency: Current.agency,
      actor: Current.agency_user,
      query: params[:q],
      status: @status,
      responsible_office_id: params[:responsible_office_id],
      responsible_agency_user_id: params[:responsible_agency_user_id],
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
    @supplier_planning = ListDepartureArrangements.call(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure
    )
    if Current.agency_user.permitted?(:manage_departures)
      @client_offers = ListDepartureServiceOffers.call(
        agency: Current.agency,
        actor: Current.agency_user,
        departure: @departure
      )
    end
    @attention_findings = Current.agency.supplier_attention_findings
      .where(departure_id: @departure.id)
      .visible_at
      .includes(:supplier_arrangement)
      .order(:attention_at, :id)
      .to_a
    @attention_findings_by_arrangement_id = @attention_findings.group_by(&:supplier_arrangement_id)
  end

  def new
    defaults = CreateDeparture.proposed_attributes(
      agency: Current.agency,
      actor: Current.agency_user,
      current_office: Current.office
    )
    @departure = departures_scope.new(defaults)
  end

  def create
    result = CreateDeparture.new(
      agency: Current.agency,
      actor: Current.agency_user,
      attributes: departure_params,
      current_office: Current.office
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

  def activate
    ActivateDeparture.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_path(@departure), notice: "Departure activated."
  rescue AgencyCommand::Error => error
    @activation_blockers = @departure.activation_blockers
    rescue_departure_error(error, "departure_activations/show")
  end
end
