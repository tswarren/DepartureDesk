class SupplierCostUsageAssumptionsController < ApplicationController
  include SupplierCostAccess

  before_action :set_assumption, only: %i[update destroy]

  def create
    result = CreateSupplierCostUsageAssumption.new(
      agency: Current.agency, actor: Current.agency_user, arrangement_item: @arrangement_item,
      attributes: assumption_params, idempotency_key: params[:idempotency_key]
    ).call
    redirect_to arrangement_location("assumption-#{result.record.id}"), notice: "Cost assumption saved."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def update
    UpdateSupplierCostUsageAssumption.new(
      agency: Current.agency, actor: Current.agency_user, assumption: @assumption,
      attributes: assumption_params, lock_version: assumption_params[:lock_version]
    ).call
    redirect_to arrangement_location("assumption-#{@assumption.id}"), notice: "Cost assumption updated."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def destroy
    RemoveSupplierCostUsageAssumption.new(
      agency: Current.agency, actor: Current.agency_user, assumption: @assumption,
      lock_version: params[:lock_version]
    ).call
    redirect_to arrangement_location("item-#{@arrangement_item.id}"), notice: "Cost assumption removed."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  private

  def set_assumption
    @assumption = @supplier_arrangement_version.supplier_cost_usage_assumptions
      .where(arrangement_item_id: @arrangement_item.id).find(params[:id])
  end

  def assumption_params
    params.fetch(:supplier_cost_usage_assumption, {}).permit(
      :service_occurrence_id, :supplier_resource_id, :expected_resource_units,
      :expected_persons, :expected_billable_nights, :lock_version
    )
  end
end
