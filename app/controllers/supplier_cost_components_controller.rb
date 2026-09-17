class SupplierCostComponentsController < ApplicationController
  include SupplierCostAccess

  before_action :set_cost_source
  before_action :set_cost_definition
  before_action :set_component, only: %i[update destroy]

  def create
    result = CreateSupplierCostComponent.new(
      agency: Current.agency, actor: Current.agency_user, definition: @supplier_cost_definition,
      attributes: component_params, base_links: base_links,
      definition_lock_version: params[:definition_lock_version], idempotency_key: params[:idempotency_key]
    ).call
    redirect_to arrangement_location("component-#{result.record.id}"), notice: "Cost component saved."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def update
    UpdateSupplierCostComponent.new(
      agency: Current.agency, actor: Current.agency_user, component: @supplier_cost_component,
      attributes: component_params, base_links:, lock_version: component_params[:lock_version],
      definition_lock_version: params[:definition_lock_version]
    ).call
    redirect_to arrangement_location("component-#{@supplier_cost_component.id}"), notice: "Cost component updated."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def destroy
    RemoveSupplierCostComponent.new(
      agency: Current.agency, actor: Current.agency_user, component: @supplier_cost_component,
      definition_lock_version: params[:definition_lock_version],
      dependent_base_link_ids: params[:dependent_base_link_ids]
    ).call
    redirect_to arrangement_location("definition-#{@supplier_cost_definition.id}"), notice: "Cost component removed."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  def reorder
    ReorderSupplierCostComponents.new(
      agency: Current.agency, actor: Current.agency_user, definition: @supplier_cost_definition,
      supplier_cost_component_ids: params[:supplier_cost_component_ids],
      definition_lock_version: params[:definition_lock_version]
    ).call
    redirect_to arrangement_location("definition-#{@supplier_cost_definition.id}"),
      notice: "Cost components reordered."
  rescue AgencyCommand::Error => error
    handle_cost_error(error)
  end

  private

  def set_component
    @supplier_cost_component = @supplier_cost_definition.supplier_cost_components.find(params[:id])
  end

  def component_params
    params.fetch(:supplier_cost_component, {}).permit(
      :label, :economic_role, :calculation_kind, :amount, :amount_minor_units, :rate, :percentage,
      :minimum_amount, :minimum_minor_units, :minimum_quantity, :quantity_basis,
      :participant_category_id, :occupancy_position_from, :occupancy_position_to,
      :percentage_treatment, :pass_through, :lock_version
    )
  end

  def base_links
    raw = params.permit(base_links: [ :base_component_id, :direction ]).fetch(:base_links, [])
    entries = raw.is_a?(Array) ? raw : raw.values
    entries.filter_map.with_index do |entry, index|
      attrs = entry.to_h.with_indifferent_access
      next if attrs[:base_component_id].blank?

      {
        base_component_id: attrs[:base_component_id],
        direction: attrs[:direction].presence || "add",
        position: index + 1
      }
    end
  end
end
