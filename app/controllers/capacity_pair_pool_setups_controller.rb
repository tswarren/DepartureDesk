class CapacityPairPoolSetupsController < ApplicationController
  include ItemCapacityAccess

  COMMAND = ConfigureCapacityPairWithPool

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_capacity_context
  before_action :set_service_occurrence
  before_action :set_supplier_resource

  def create
    result = ConfigureCapacityPairWithPool.new(
      agency: Current.agency,
      actor: Current.agency_user,
      item: @arrangement_item,
      service_occurrence: @service_occurrence,
      supplier_resource: @supplier_resource,
      pool_attributes: capacity_pool_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_item_capacity_path(
      @departure,
      @supplier_arrangement,
      @arrangement_item,
      anchor: "capacity-pool-#{result.record.id}"
    ), notice: "Capacity pair and first Pool saved."
  rescue AgencyCommand::Error => error
    @capacity_pool_definition = CapacityPoolDefinition.new(
      capacity_pool_params.except(:inventory_mode, :measurement_basis, :lock_version)
    )
    @pool_setup_members = [ @service_occurrence.id, @supplier_resource.id ]
    @submitted_capacity_pool_params = capacity_pool_params
    @pool_setup_idempotency_key = params[:idempotency_key]
    add_capacity_error(@capacity_pool_definition, error)
    render_capacity_show
  end
end
