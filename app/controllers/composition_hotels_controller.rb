# frozen_string_literal: true

class CompositionHotelsController < ApplicationController
  include DepartureAccess
  include HotelArrangementAccess

  before_action :require_composition_access!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :assign_hotel_composition_context

  def new
    @item_attributes = item_defaults
    @occurrence_attributes = occurrence_defaults
    @arrangement_attributes = arrangement_defaults
    @idempotency_key = SecureRandom.uuid
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @item_attributes = item_params.to_h
    @occurrence_attributes = stay_occurrence_attributes
    @arrangement_attributes = arrangement_params.to_h

    _arrangement, item = save_new_hotel_stay!(
      departure: @departure,
      arrangement: nil,
      item_name: @item_attributes[:name],
      occurrence_attributes: @occurrence_attributes,
      idempotency_key: @idempotency_key,
      contracting_supplier_id: @arrangement_attributes[:contracting_supplier_id]
    )
    arrangement = item.supplier_arrangement
    redirect_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item),
      notice: "Hotel stay saved. Add room categories and nights next."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :new)
  end

  private

  def item_defaults
    { name: params.dig(:item, :name) }
  end

  def arrangement_defaults
    { contracting_supplier_id: params.dig(:arrangement, :contracting_supplier_id) }
  end

  def occurrence_defaults
    {
      starts_on: params.dig(:occurrence, :starts_on),
      ends_on: params.dig(:occurrence, :ends_on),
      starts_at_local: params.dig(:occurrence, :starts_at_local).presence || "15:00",
      ends_at_local: params.dig(:occurrence, :ends_at_local).presence || "12:00",
      time_zone: params.dig(:occurrence, :time_zone).presence || @departure.time_zone
    }
  end

  def item_params
    params.fetch(:item, ActionController::Parameters.new).permit(:name)
  end

  def arrangement_params
    params.fetch(:arrangement, ActionController::Parameters.new).permit(:contracting_supplier_id)
  end
end
