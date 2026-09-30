# frozen_string_literal: true

class CruiseCabinCategoriesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!
  before_action :require_editable_draft!, except: :index
  before_action :set_cabin_category, only: %i[edit update]
  before_action :set_removable_category, only: :destroy

  def index
    @workspace = CompileCruiseCabinInventoryWorkspace.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      shape: @shape
    ).call
    @editable = @supplier_arrangement_version&.draft?
    @can_change_inventory = @supplier_arrangement.governing_version&.activated?
  end

  def new
    @cabin_rows = Array.new(3) { SaveCruiseCabinCategoryBatch.blank_row }
    @version_lock_version = @supplier_arrangement_version.lock_version
  end

  def create
    result = SaveCruiseCabinCategoryBatch.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      rows: cabin_row_params,
      version_lock_version: params.require(:version_lock_version)
    ).call

    if result.saved?
      redirect_to departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement),
        notice: cabin_save_notice(result.saved_count)
    else
      @cabin_rows = result.unresolved_rows
      @version_lock_version = result.version_lock_version
      @form_error = result.error_message
      flash.now[:alert] = result.error_message
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @idempotency_key = SecureRandom.uuid
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
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
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
      pool_lock_version: params.require(:pool_lock_version),
      idempotency_key: @idempotency_key
    ).call

    redirect_to departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement),
      notice: "Cabin category updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    render :edit, status: :unprocessable_entity
  end

  def destroy
    RemoveCruiseCabinCategory.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      resource: @supplier_resource,
      version_lock_version: params.require(:version_lock_version)
    ).call

    redirect_to departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement),
      notice: "Cabin category removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_cruise_cabin_categories_path(@departure, @supplier_arrangement),
      alert: error.message
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

  def set_removable_category
    @supplier_resource = @shape.item.supplier_resources.find(params[:resource_id])
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
    @removable = RemoveCruiseCabinCategory.possible?(
      version: @supplier_arrangement_version,
      resource: @supplier_resource
    )
  end

  def cabin_row_params
    Array(params[:rows]).map do |row|
      row.permit(
        :idempotency_key, :supplier_code, :name, :maximum_occupancy,
        :inventory_mode, :proposed_opening_quantity
      ).to_h
    end
  end

  def cabin_save_notice(count)
    count == 1 ? "Cabin category saved." : "#{count} cabin categories saved."
  end

  def resource_params
    params.fetch(:resource, ActionController::Parameters.new).permit(
      :name, :supplier_code, :maximum_occupancy
    )
  end

  def pool_update_params
    params.fetch(:pool, ActionController::Parameters.new).permit(
      :proposed_opening_quantity, :notes,
      :evidence_kind, :evidence_on, :evidence_reference_note, :evidence_external_reference,
      :override, :override_reason
    )
  end
end
