class SupplierCostDefinitionsController < ApplicationController
  include SupplierCostAccess

  before_action :set_cost_source
  before_action :set_cost_definition, only: %i[update destroy forecast_ready]

  def create
    result = CreateSupplierCostDefinition.new(
      agency: Current.agency, actor: Current.agency_user, source: @supplier_cost_source,
      attributes: definition_params, source_lock_version: params[:source_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to arrangement_location("definition-#{result.record.id}"), notice: "Cost stage saved."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def update
    UpdateSupplierCostDefinition.new(
      agency: Current.agency, actor: Current.agency_user, definition: @supplier_cost_definition,
      attributes: definition_params, lock_version: definition_params[:lock_version]
    ).call
    redirect_to arrangement_location("definition-#{@supplier_cost_definition.id}"), notice: "Cost stage updated."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def destroy
    RemoveSupplierCostDefinition.new(
      agency: Current.agency, actor: Current.agency_user, definition: @supplier_cost_definition,
      source_lock_version: params[:source_lock_version]
    ).call
    redirect_to arrangement_location("cost-source-#{@supplier_cost_source.id}"), notice: "Cost stage removed."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def forecast_ready
    MarkCostDefinitionForecastReady.new(
      agency: Current.agency, actor: Current.agency_user, definition: @supplier_cost_definition,
      lock_version: params[:lock_version], readiness_provenance: params[:readiness_provenance]
    ).call
    redirect_to arrangement_location("definition-#{@supplier_cost_definition.id}"),
      notice: "Cost stage marked forecast ready."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  private

  def definition_params
    params.fetch(:supplier_cost_definition, {}).permit(
      :stage, :mode, :currency, :rounding_mode, :zero_cost_reason, :lock_version
    )
  end
end
