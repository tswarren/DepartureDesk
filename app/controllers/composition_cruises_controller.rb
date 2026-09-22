# frozen_string_literal: true

class CompositionCruisesController < ApplicationController
  include DepartureAccess
  include CompositionAccess
  include SupplierArrangementAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!

  def new
    @arrangement_attributes = arrangement_defaults
    @item_attributes = item_defaults
    @occurrence_attributes = occurrence_defaults
    @idempotency_key = SecureRandom.uuid
    @return_intent = params[:return_intent].to_s
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @arrangement_attributes = arrangement_params.to_h
    @item_attributes = item_params.to_h
    @occurrence_attributes = occurrence_params.to_h
    @return_intent = params[:return_intent].to_s.presence || commit_return_intent

    result = CreateCruiseSailingSetup.new(
      agency: Current.agency,
      actor: Current.agency_user,
      departure: @departure,
      arrangement_attributes: @arrangement_attributes,
      item_attributes: @item_attributes,
      occurrence_attributes: @occurrence_attributes,
      idempotency_key: @idempotency_key
    ).call

    arrangement = result.record.arrangement
    if @return_intent == "suppliers"
      redirect_to suppliers_departure_composition_path(@departure), notice: "Cruise sailing saved."
    else
      redirect_to departure_arrangement_cruise_path(@departure, arrangement),
        notice: "Cruise sailing saved. Add a cabin category next."
    end
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @form_error = error.message
    flash.now[:alert] = error.message
    render :new, status: :unprocessable_entity
  end

  private

  def arrangement_defaults
    {
      name: params.dig(:arrangement, :name),
      contracting_supplier_id: params.dig(:arrangement, :contracting_supplier_id),
      supplier_contact_id: params.dig(:arrangement, :supplier_contact_id)
    }
  end

  def item_defaults
    {
      name: params.dig(:item, :name),
      default_service_provider_id: params.dig(:item, :default_service_provider_id)
    }
  end

  def occurrence_defaults
    {
      name: params.dig(:occurrence, :name),
      starts_on: params.dig(:occurrence, :starts_on),
      ends_on: params.dig(:occurrence, :ends_on),
      time_zone: params.dig(:occurrence, :time_zone).presence || @departure.time_zone
    }
  end

  def arrangement_params
    params.fetch(:arrangement, ActionController::Parameters.new).permit(
      :name, :contracting_supplier_id, :supplier_contact_id
    )
  end

  def item_params
    params.fetch(:item, ActionController::Parameters.new).permit(
      :name, :default_service_provider_id
    )
  end

  def occurrence_params
    params.fetch(:occurrence, ActionController::Parameters.new).permit(
      :name, :starts_on, :ends_on, :time_zone
    )
  end

  def commit_return_intent
    case params[:commit].to_s
    when /return to Suppliers/i then "suppliers"
    else "continue"
    end
  end
end
