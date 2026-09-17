class ServiceOccurrencesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_editable_draft_version
  before_action :set_arrangement_item
  before_action :set_item_definition
  before_action :set_service_occurrence, only: %i[edit update destroy]
  before_action :set_service_occurrence_definition, only: %i[edit update]

  def new
    @service_occurrence_definition = @supplier_arrangement_version.service_occurrence_definitions.new(
      time_zone: @departure.time_zone
    )
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateServiceOccurrence.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      attributes: service_occurrence_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "occurrence-#{result.record.id}"), notice: "Occurrence saved."
  rescue AgencyCommand::Error => error
    @service_occurrence_definition = @supplier_arrangement_version.service_occurrence_definitions.new(service_occurrence_params)
    @idempotency_key = params[:idempotency_key]
    add_arrangement_error(@service_occurrence_definition, error)
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdateServiceOccurrence.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @service_occurrence_definition,
      attributes: service_occurrence_params,
      lock_version: service_occurrence_params[:lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "occurrence-#{@service_occurrence.id}"), notice: "Occurrence updated."
  rescue AgencyCommand::Error => error
    @service_occurrence_definition.assign_attributes(service_occurrence_params.except(:lock_version))
    add_arrangement_error(@service_occurrence_definition, error)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveServiceOccurrence.new(
      agency: Current.agency,
      actor: Current.agency_user,
      occurrence: @service_occurrence,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "item-#{@arrangement_item.id}"), notice: "Occurrence removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), alert: error.message
  end

  private

  def service_occurrence_params
    params.fetch(:service_occurrence_definition, ActionController::Parameters.new).permit(
      :name, :description, :starts_on, :ends_on, :starts_at_local, :ends_at_local, :time_zone, :service_provider_id, :lock_version
    )
  end
end
