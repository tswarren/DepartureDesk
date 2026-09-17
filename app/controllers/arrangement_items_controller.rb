class ArrangementItemsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_initial_version
  before_action :set_arrangement_item, only: %i[edit update destroy]
  before_action :set_item_definition, only: %i[edit update]

  def new
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.new
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateArrangementItem.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      attributes: arrangement_item_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "item-#{result.record.id}"), notice: "Item saved."
  rescue AgencyCommand::Error => error
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.new(arrangement_item_params)
    @idempotency_key = params[:idempotency_key]
    add_arrangement_error(@arrangement_item_definition, error)
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    UpdateArrangementItem.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @arrangement_item_definition,
      attributes: arrangement_item_params,
      lock_version: arrangement_item_params[:lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement, anchor: "item-#{@arrangement_item.id}"), notice: "Item updated."
  rescue AgencyCommand::Error => error
    @arrangement_item_definition.assign_attributes(arrangement_item_params.except(:lock_version))
    add_arrangement_error(@arrangement_item_definition, error)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveArrangementItem.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), notice: "Item removed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), alert: error.message
  end

  def reorder
    ReorderArrangementItems.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      arrangement_item_ids: params[:arrangement_item_ids],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_path(
      @departure, @supplier_arrangement, structure_mode: "items"
    ), notice: "Items reordered."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_path(
      @departure, @supplier_arrangement, structure_mode: "items"
    ), alert: error.message
  end

  private

  def arrangement_item_params
    params.fetch(:arrangement_item_definition, ActionController::Parameters.new).permit(
      :name, :description, :category, :other_category_label, :default_service_provider_id, :lock_version
    )
  end
end
