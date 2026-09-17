class SupplierCostSourcesController < ApplicationController
  include SupplierCostAccess

  before_action :set_cost_source, only: %i[update destroy]

  def create
    result = CreateSupplierCostSource.new(
      agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
      attributes: source_params.merge(arrangement_item_id: @arrangement_item&.id),
      version_lock_version: params[:version_lock_version], idempotency_key: params[:idempotency_key]
    ).call
    redirect_to arrangement_location("cost-source-#{result.record.id}"), notice: "Cost source saved."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def update
    UpdateSupplierCostSource.new(
      agency: Current.agency, actor: Current.agency_user, source: @supplier_cost_source,
      attributes: source_params, lock_version: source_params[:lock_version]
    ).call
    redirect_to arrangement_location("cost-source-#{@supplier_cost_source.id}"), notice: "Cost source updated."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def destroy
    RemoveSupplierCostSource.new(
      agency: Current.agency, actor: Current.agency_user, source: @supplier_cost_source,
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to arrangement_location(@arrangement_item ? "item-#{@arrangement_item.id}" : "arrangement-costs"),
      notice: "Cost source removed."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def reorder
    ReorderSupplierCostSources.new(
      agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
      arrangement_item: @arrangement_item, supplier_cost_source_ids: params[:supplier_cost_source_ids],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to arrangement_location(@arrangement_item ? "item-#{@arrangement_item.id}" : "arrangement-costs"),
      notice: "Cost sources reordered."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  private

  def source_params
    params.fetch(:supplier_cost_source, {}).permit(
      :label, :notes, :charging_supplier_id, :service_occurrence_id, :supplier_resource_id, :lock_version
    )
  end
end
