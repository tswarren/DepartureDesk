class CapacityPoolsController < ApplicationController
  include ItemCapacityAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_capacity_context
  before_action :set_capacity_pair
  before_action :set_capacity_pool_definition, only: %i[edit update destroy]

  def new
    @capacity_pool_definition = CapacityPoolDefinition.new
    @idempotency_key = SecureRandom.uuid
  end

  def create
    result = CreateCapacityPool.new(
      agency: Current.agency,
      actor: Current.agency_user,
      pair: @capacity_pair,
      attributes: capacity_pool_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item, anchor: "capacity-pool-#{result.record.id}"), notice: "Capacity pool saved."
  rescue AgencyCommand::Error => error
    @capacity_pool_definition = CapacityPoolDefinition.new(capacity_pool_params.except(:inventory_mode, :measurement_basis, :lock_version))
    @pool_form_pair_id = @capacity_pair.id
    @submitted_capacity_pool_params = capacity_pool_params
    @idempotency_key_by_pair_id = { @capacity_pair.id => params[:idempotency_key] }
    add_capacity_error(@capacity_pool_definition, error)
    render_capacity_show
  end

  def edit
  end

  def update
    UpdateCapacityPool.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @capacity_pool_definition,
      attributes: capacity_pool_params,
      lock_version: capacity_pool_params[:lock_version]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item, anchor: "capacity-pool-#{@capacity_pool_definition.capacity_pool_id}"), notice: "Capacity pool updated."
  rescue AgencyCommand::Error => error
    @capacity_pool_definition.assign_attributes(capacity_pool_params.except(:inventory_mode, :measurement_basis, :lock_version))
    @submitted_capacity_pool_params = capacity_pool_params
    add_capacity_error(@capacity_pool_definition, error)
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveCapacityPool.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @capacity_pool_definition,
      version_lock_version: params[:version_lock_version],
      lock_version: params[:lock_version]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item), notice: "Capacity pool removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    render_capacity_show
  end

  def reorder
    ReorderCapacityPools.new(
      agency: Current.agency,
      actor: Current.agency_user,
      pair: @capacity_pair,
      capacity_pool_ids: params[:capacity_pool_ids],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item), notice: "Capacity pools reordered."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    render_capacity_show
  end
end
