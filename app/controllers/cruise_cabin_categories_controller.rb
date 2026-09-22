# frozen_string_literal: true

class CruiseCabinCategoriesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!
  before_action :require_editable_draft!
  before_action :set_cabin_category, only: %i[edit update]

  def new
    @resource_attributes = resource_defaults
    @pool_attributes = pool_defaults
    @idempotency_key = SecureRandom.uuid
    @return_intent = params[:return_intent].to_s
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @resource_attributes = resource_params.to_h
    @pool_attributes = pool_create_params.to_h
    @return_intent = params[:return_intent].to_s.presence || commit_return_intent

    CreateCruiseCabinCategorySetup.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource_attributes: @resource_attributes,
      pool_attributes: @pool_attributes,
      version_lock_version: params.require(:version_lock_version),
      idempotency_key: @idempotency_key
    ).call

    if @return_intent == "add_another"
      redirect_to new_departure_arrangement_cruise_cabin_category_path(
        @departure, @supplier_arrangement
      ), notice: "Cabin category saved. Add another when ready."
    else
      redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
        notice: "Cabin category saved."
    end
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  def edit
    @resource_attributes = {
      name: @resource_definition.name,
      supplier_code: @resource_definition.supplier_code,
      maximum_occupancy: @resource_definition.maximum_occupancy
    }
    @pool_attributes = {
      proposed_opening_quantity: @pool_definition.proposed_opening_quantity,
      notes: @pool_definition.notes,
      evidence_kind: @pool_definition.evidence_kind,
      evidence_on: @pool_definition.evidence_on,
      evidence_reference_note: @pool_definition.evidence_reference_note,
      evidence_external_reference: @pool_definition.evidence_external_reference,
      override: @pool_definition.override?,
      override_reason: @pool_definition.override_reason
    }
  end

  def update
    @resource_attributes = resource_params.to_h
    @pool_attributes = pool_update_params.to_h

    UpdateCruiseCabinCategorySetup.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      resource_attributes: @resource_attributes,
      pool_attributes: @pool_attributes,
      version_lock_version: params.require(:version_lock_version),
      resource_lock_version: params.require(:resource_lock_version),
      pool_lock_version: params.require(:pool_lock_version)
    ).call

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      notice: "Cabin category updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    render :edit, status: :unprocessable_entity
  end

  private

  def require_compatible_cruise_shape!
    @shape = DetectCruiseArrangementShape.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement
    ).call
    @supplier_arrangement_version = @shape.version
    return if @shape.compatible?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "This Arrangement uses an advanced structure. Open advanced Supplier planning."
  end

  def require_editable_draft!
    return if @supplier_arrangement_version&.draft?

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      alert: "Create a successor draft before editing cabin categories."
  end

  def set_cabin_category
    item = @shape.item
    @supplier_resource = item.supplier_resources.find(params[:resource_id])
    @resource_definition = @supplier_arrangement_version.supplier_resource_definitions.find_by!(
      supplier_resource: @supplier_resource
    )
    @pool = @supplier_arrangement.capacity_pools.find_by!(
      arrangement_item: item,
      service_occurrence: @shape.occurrence,
      supplier_resource: @supplier_resource
    )
    @pool_definition = @supplier_arrangement_version.capacity_pool_definitions.find_by!(
      capacity_pool: @pool
    )
  end

  def resource_defaults
    {
      name: params.dig(:resource, :name),
      supplier_code: params.dig(:resource, :supplier_code),
      maximum_occupancy: params.dig(:resource, :maximum_occupancy)
    }
  end

  def pool_defaults
    {
      inventory_mode: params.dig(:pool, :inventory_mode).presence || "block",
      proposed_opening_quantity: params.dig(:pool, :proposed_opening_quantity),
      notes: params.dig(:pool, :notes),
      evidence_kind: params.dig(:pool, :evidence_kind),
      evidence_on: params.dig(:pool, :evidence_on),
      evidence_reference_note: params.dig(:pool, :evidence_reference_note),
      evidence_external_reference: params.dig(:pool, :evidence_external_reference),
      override: params.dig(:pool, :override),
      override_reason: params.dig(:pool, :override_reason)
    }
  end

  def resource_params
    params.fetch(:resource, ActionController::Parameters.new).permit(
      :name, :supplier_code, :maximum_occupancy
    )
  end

  def pool_create_params
    params.fetch(:pool, ActionController::Parameters.new).permit(
      :inventory_mode, :proposed_opening_quantity, :notes,
      :evidence_kind, :evidence_on, :evidence_reference_note, :evidence_external_reference,
      :override, :override_reason
    )
  end

  def pool_update_params
    params.fetch(:pool, ActionController::Parameters.new).permit(
      :proposed_opening_quantity, :notes,
      :evidence_kind, :evidence_on, :evidence_reference_note, :evidence_external_reference,
      :override, :override_reason
    )
  end

  def commit_return_intent
    case params[:commit].to_s
    when /add another/i then "add_another"
    else "workspace"
    end
  end
end
