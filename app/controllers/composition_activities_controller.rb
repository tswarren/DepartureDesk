# frozen_string_literal: true

class CompositionActivitiesController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :assign_activity_workspace

  def new
    @arrangement_attributes = { contracting_supplier_id: params.dig(:arrangement, :contracting_supplier_id) }
    @suppliers = active_supplier_options
    @idempotency_key = SecureRandom.uuid
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    arrangement = CreateSupplierArrangement.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure,
      idempotency_key: "#{@idempotency_key}:arrangement",
      attributes: {
        name: arrangement_params[:name].presence || "Activity",
        contracting_supplier_id: arrangement_params[:contracting_supplier_id]
      }
    ).call.record
    redirect_to departure_arrangement_activity_path(@departure, arrangement),
      notice: "Activity arrangement opened. Add the activity next."
  rescue AgencyCommand::Error => error
    @arrangement_attributes = arrangement_params.to_h
    @suppliers = active_supplier_options
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def arrangement_params
    params.fetch(:arrangement, ActionController::Parameters.new).permit(:name, :contracting_supplier_id)
  end
end
