class SupplierResourcesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_initial_version
  before_action :set_arrangement_item
  before_action :set_item_definition
  before_action :set_supplier_resource, only: %i[edit update destroy]
  before_action :set_supplier_resource_definition, only: %i[edit update]

  def new
    @supplier_resource_definition = @supplier_arrangement_version.supplier_resource_definitions.new
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateSupplierResource.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      attributes: supplier_resource_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "resource-#{result.record.id}"), notice: "Resource saved."
  rescue AgencyCommand::Error => error
    @supplier_resource_definition = @supplier_arrangement_version.supplier_resource_definitions.new(supplier_resource_params)
    @idempotency_key = params[:idempotency_key]
    add_arrangement_error(@supplier_resource_definition, error)
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdateSupplierResource.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @supplier_resource_definition,
      attributes: supplier_resource_params,
      lock_version: supplier_resource_params[:lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "resource-#{@supplier_resource.id}"), notice: "Resource updated."
  rescue AgencyCommand::Error => error
    @supplier_resource_definition.assign_attributes(supplier_resource_params.except(:lock_version))
    add_arrangement_error(@supplier_resource_definition, error)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveSupplierResource.new(
      agency: Current.agency,
      actor: Current.agency_user,
      resource: @supplier_resource,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "item-#{@arrangement_item.id}"), notice: "Resource removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), alert: error.message
  end

  def reorder
    ReorderSupplierResources.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      supplier_resource_ids: params[:supplier_resource_ids],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_path(
      @departure,
      @supplier_arrangement,
      structure_mode: "resources",
      structure_item_id: @arrangement_item.id,
      anchor: "resources-#{@arrangement_item.id}"
    ), notice: "Resources reordered."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_path(
      @departure,
      @supplier_arrangement,
      structure_mode: "resources",
      structure_item_id: @arrangement_item.id,
      anchor: "resources-#{@arrangement_item.id}"
    ), alert: error.message
  end

  private

  def supplier_resource_params
    params.fetch(:supplier_resource_definition, ActionController::Parameters.new).permit(
      :name, :description, :lock_version
    )
  end
end
