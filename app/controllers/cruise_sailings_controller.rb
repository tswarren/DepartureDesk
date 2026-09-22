# frozen_string_literal: true

class CruiseSailingsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :require_compatible_cruise_shape!
  before_action :require_editable_draft!

  def edit
    @idempotency_key = SecureRandom.uuid
    assign_sailing_form_from_shape
  end

  def update
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    assign_sailing_form_from_params

    UpdateCruiseSailingSetup.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      arrangement_attributes: arrangement_params,
      item_attributes: item_params,
      occurrence_attributes: occurrence_params,
      arrangement_lock_version: params.require(:arrangement_lock_version),
      version_lock_version: params.require(:version_lock_version),
      item_lock_version: params.require(:item_lock_version),
      occurrence_lock_version: params.require(:occurrence_lock_version),
      idempotency_key: @idempotency_key
    ).call

    redirect_to departure_arrangement_cruise_path(@departure, @supplier_arrangement),
      notice: "Sailing updated."
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
      alert: "Create a successor draft before editing this sailing."
  end

  def assign_sailing_form_from_shape
    @arrangement_attributes = {
      name: @supplier_arrangement.name,
      supplier_contact_id: @supplier_arrangement.supplier_contact_id
    }
    @item_attributes = { name: @shape.item_definition.name }
    @occurrence_attributes = {
      name: @shape.occurrence_definition.name,
      starts_on: @shape.occurrence_definition.starts_on,
      ends_on: @shape.occurrence_definition.ends_on,
      time_zone: @shape.occurrence_definition.time_zone
    }
  end

  def assign_sailing_form_from_params
    @arrangement_attributes = arrangement_params.to_h
    @item_attributes = item_params.to_h
    @occurrence_attributes = occurrence_params.to_h
  end

  def arrangement_params
    params.fetch(:arrangement, ActionController::Parameters.new).permit(
      :name, :supplier_contact_id
    )
  end

  def item_params
    params.fetch(:item, ActionController::Parameters.new).permit(:name)
  end

  def occurrence_params
    params.fetch(:occurrence, ActionController::Parameters.new).permit(
      :name, :starts_on, :ends_on, :time_zone
    )
  end
end
