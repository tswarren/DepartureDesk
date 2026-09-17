class SupplierCostSetupsController < ApplicationController
  include SupplierCostAccess

  COMMAND = CreateSupplierCostSetup

  def new
    prepare_form
  end

  def create
    result = COMMAND.new(
      agency: Current.agency, actor: Current.agency_user, arrangement: @supplier_arrangement,
      source_attributes: source_params, definition_attributes: definition_params,
      component_attributes: calculated? ? component_params : nil,
      assumption_attributes: assumption_params,
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    definition = result.record.is_a?(SupplierCostComponent) ?
      result.record.supplier_cost_definition : result.record
    redirect_to review_path(definition), notice: "Initial Supplier cost saved. Review it before marking it ready."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @setup_error = error.message
    prepare_form
    render :new, status: :unprocessable_entity
  end

  private

  def prepare_form
    @occurrence_definitions = @arrangement_item ?
      @supplier_arrangement_version.service_occurrence_definitions
        .where(arrangement_item_id: @arrangement_item.id).order(:starts_on, :id).to_a : []
    @resource_definitions = @arrangement_item ?
      @supplier_arrangement_version.supplier_resource_definitions
        .where(arrangement_item_id: @arrangement_item.id).order(:position, :id).to_a : []
    @categories = @arrangement_item ?
      @supplier_arrangement_version.supplier_cost_participant_categories
        .where(arrangement_item_id: @arrangement_item.id).order(:position, :id).to_a : []
  end

  def source_params
    params.fetch(:supplier_cost_source, {}).permit(
      :label, :notes, :charging_supplier_id, :arrangement_item_id,
      :service_occurrence_id, :supplier_resource_id
    ).tap do |attributes|
      attributes[:arrangement_item_id] = @arrangement_item.id if @arrangement_item
    end
  end

  def definition_params
    params.fetch(:supplier_cost_definition, {}).permit(
      :stage, :mode, :currency, :rounding_mode, :zero_cost_reason
    )
  end

  def component_params
    params.fetch(:supplier_cost_component, {}).permit(
      :label, :economic_role, :calculation_kind, :amount, :percentage,
      :minimum_amount, :minimum_quantity, :quantity_basis, :participant_category_id,
      :occupancy_position_from, :occupancy_position_to, :percentage_treatment, :pass_through
    )
  end

  def assumption_params
    params.fetch(:supplier_cost_usage_assumption, {}).permit(
      :expected_resource_units, :expected_persons, :expected_billable_nights
    )
  end

  def calculated?
    params.dig(:supplier_cost_definition, :mode).to_s == "calculated"
  end

  def review_path(definition)
    if @arrangement_item
      departure_arrangement_item_cost_definition_review_path(
        @departure, @supplier_arrangement, @arrangement_item,
        definition.supplier_cost_source, definition
      )
    else
      departure_arrangement_cost_definition_review_path(
        @departure, @supplier_arrangement, definition.supplier_cost_source, definition
      )
    end
  end
end
