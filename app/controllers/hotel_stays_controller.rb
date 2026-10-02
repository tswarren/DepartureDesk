# frozen_string_literal: true

class HotelStaysController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_view!, only: :edit
  before_action :require_departure_management!, except: :edit
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_version
  before_action :set_hotel_item, only: %i[edit update]
  before_action :assign_hotel_composition_context
  before_action :assign_stay_shape, only: %i[edit update]

  def new
    @editable = hotel_editable?
    @item_attributes = { name: params.dig(:item, :name) }
    @occurrence_attributes = occurrence_defaults
    @idempotency_key = SecureRandom.uuid
  end

  def create
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @item_attributes = params.fetch(:item, ActionController::Parameters.new).permit(:name).to_h
    @occurrence_attributes = stay_occurrence_attributes
    _arrangement, item = save_new_hotel_stay!(
      departure: @departure,
      arrangement: @supplier_arrangement,
      item_name: @item_attributes[:name],
      occurrence_attributes: @occurrence_attributes,
      idempotency_key: @idempotency_key
    )
    redirect_to item_inventory_departure_arrangement_hotel_path(@departure, @supplier_arrangement, item),
      notice: "Hotel stay saved. Add room categories next."
  rescue AgencyCommand::Error => error
    @editable = hotel_editable?
    hotel_command_error(error, :new)
  end

  def edit
    @editable = hotel_editable? && @shape.supported?
    @occurrence_attributes = occurrence_from_stay
    @idempotency_key = SecureRandom.uuid
  end

  def update
    assign_hotel_shape
    unless hotel_editable? && @shape.supported? && @shape.stay_definition
      @form_error = @shape.reasons.first || "This stay cannot be edited here."
      @editable = false
      @occurrence_attributes = stay_occurrence_attributes
      render :edit, status: :unprocessable_entity
      return
    end

    definition = @shape.stay_definition
    ensure_hotel_times_paired!(stay_occurrence_attributes)
    UpdateServiceOccurrence.new(
      **hotel_command_context,
      definition: definition,
      lock_version: params[:definition_lock_version],
      attributes: stay_occurrence_attributes.merge(
        name: definition.name,
        description: definition.description
      )
    ).call
    redirect_to path_after_hotel_edit(departure_arrangement_hotel_path(@departure, @supplier_arrangement)),
      notice: "Stay saved."
  rescue AgencyCommand::Error => error
    @editable = hotel_editable?
    @occurrence_attributes = stay_occurrence_attributes
    hotel_command_error(error, :edit)
  end

  private

  def assign_stay_shape
    assign_hotel_shape
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

  def occurrence_from_stay
    stay = @shape.stay_definition
    return occurrence_defaults if stay.nil?

    {
      starts_on: stay.starts_on,
      ends_on: stay.ends_on,
      starts_at_local: stay.starts_at_local,
      ends_at_local: stay.ends_at_local,
      time_zone: stay.time_zone
    }
  end
end
