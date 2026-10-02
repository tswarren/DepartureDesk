# frozen_string_literal: true

class CompositionTransportationsController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :assign_transportation_workspace

  def new
    @arrangement_attributes = { contracting_supplier_id: params.dig(:arrangement, :contracting_supplier_id) }
    @suppliers = active_supplier_options
    @idempotency_key = SecureRandom.uuid
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    arrangement = CreateSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      idempotency_key: "#{@idempotency_key}:arrangement",
      attributes: {
        name: arrangement_params[:name].presence || "Transportation",
        contracting_supplier_id: arrangement_params[:contracting_supplier_id]
      }
    ).call.record
    redirect_to departure_arrangement_transportation_path(@departure, arrangement),
      notice: "Transportation arrangement opened. Add the segments next."
  rescue AgencyCommand::Error => error
    @arrangement_attributes = arrangement_params.to_h
    @suppliers = active_supplier_options
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def active_supplier_options
    Current.agency.suppliers.where(status: "active").ordered_for_directory
  end

  def arrangement_params
    params.fetch(:arrangement, ActionController::Parameters.new).permit(:name, :contracting_supplier_id)
  end
end
