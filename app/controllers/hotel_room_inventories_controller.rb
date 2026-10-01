# frozen_string_literal: true

class HotelRoomInventoriesController < ApplicationController
  include HotelArrangementAccess

  before_action :require_departure_view!, only: :show
  before_action :require_departure_management!, except: :show
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_supplier_arrangement
  before_action :set_hotel_version
  before_action :set_hotel_item
  before_action :assign_hotel_composition_context
  before_action :prepare_inventory

  def show
  end

  def create_resource
    return render_blocked if @shape.blocked? || !@editable

    @resource_attributes = resource_params.to_h
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    ActiveRecord::Base.transaction do
      version = reload_draft_version!
      resource = CreateSupplierResource.new(
        **hotel_command_context,
        item: @arrangement_item,
        version_lock_version: version.lock_version,
        idempotency_key: "#{@idempotency_key}:resource",
        attributes: {
          name: @resource_attributes[:name],
          maximum_occupancy: @resource_attributes[:maximum_occupancy].presence || 4
        }
      ).call.record
      assign_hotel_shape
      classify_stay_resource!(item: @arrangement_item, stay_definition: @shape.stay_definition, resource: resource)
    end
    redirect_to inventory_path, notice: "Room category saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :show)
  end

  def update_resource
    return render_blocked if @shape.blocked? || !@editable

    definition = @shape.resources.find { |row| row.supplier_resource_id == params[:resource_id] }
    raise ActiveRecord::RecordNotFound if definition.nil?

    UpdateSupplierResource.new(
      **hotel_command_context,
      definition: definition,
      lock_version: params[:definition_lock_version],
      attributes: {
        name: resource_params[:name],
        maximum_occupancy: resource_params[:maximum_occupancy]
      }
    ).call
    redirect_to inventory_path, notice: "Room category saved."
  rescue AgencyCommand::Error => error
    @resource_error_id = params[:resource_id]
    hotel_command_error(error, :show)
  end

  def create_night
    return render_blocked if @shape.blocked? || !@editable

    @night_attributes = night_params.to_h
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    version = reload_draft_version!
    CreateServiceOccurrence.new(
      **hotel_command_context,
      item: @arrangement_item,
      version_lock_version: version.lock_version,
      idempotency_key: "#{@idempotency_key}:night",
      attributes: {
        name: night_name(@night_attributes[:starts_on]),
        starts_on: @night_attributes[:starts_on],
        ends_on: @night_attributes[:starts_on],
        time_zone: @departure.time_zone
      }
    ).call
    redirect_to inventory_path, notice: "Room night saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :show)
  end

  def create_opening
    cell = opening_cell
    unless @editable && cell&.supported? && cell.pool_definition.nil?
      @form_error = cell&.reason || @shape.reasons.first || "This contracted room count cannot be saved here."
      @opening_target = opening_target
      render :show, status: :unprocessable_entity
      return
    end

    @opening_attributes = opening_params.to_h
    @opening_target = opening_target
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    version = reload_draft_version!
    ConfigureCapacityPairWithPool.new(
      **hotel_command_context,
      item: @arrangement_item,
      service_occurrence: cell.night_definition.service_occurrence,
      supplier_resource: cell.resource_definition.supplier_resource,
      version_lock_version: version.lock_version,
      idempotency_key: "#{@idempotency_key}:opening",
      pool_attributes: {
        label: "#{cell.night_definition.name} #{cell.resource_definition.name}",
        inventory_mode: "block",
        measurement_basis: "resource_units",
        unit_label: "rooms",
        proposed_opening_quantity: @opening_attributes[:proposed_opening_quantity],
        evidence_kind: @opening_attributes[:evidence_kind],
        evidence_on: @opening_attributes[:evidence_on],
        evidence_reference_note: @opening_attributes[:evidence_reference_note]
      }
    ).call
    redirect_to inventory_path, notice: "#{cell.night_definition.name} #{cell.resource_definition.name} saved."
  rescue AgencyCommand::Error => error
    @opening_target = opening_target
    hotel_command_error(error, :show)
  end

  def update_opening
    cell = @shape.cells.find { |row| row.pool_definition&.id == params[:pool_definition_id] }
    unless @editable && cell&.supported?
      @form_error = cell&.reason || @shape.reasons.first || "This contracted room count cannot be saved here."
      @opening_target = params[:pool_definition_id]
      render :show, status: :unprocessable_entity
      return
    end

    @opening_attributes = opening_params.to_h
    @opening_target = cell.pool_definition.id
    UpdateCapacityPool.new(
      **hotel_command_context,
      definition: cell.pool_definition,
      lock_version: params[:definition_lock_version],
      attributes: { proposed_opening_quantity: @opening_attributes[:proposed_opening_quantity] }
    ).call
    redirect_to inventory_path, notice: "#{cell.night_definition.name} #{cell.resource_definition.name} saved."
  rescue AgencyCommand::Error => error
    @opening_target = params[:pool_definition_id]
    hotel_command_error(error, :show)
  end

  private

  def prepare_inventory
    assign_hotel_shape
    @editable = hotel_editable? && @shape.supported?
    @resource_attributes ||= { name: nil, maximum_occupancy: 4 }
    @night_attributes ||= { starts_on: nil }
    @idempotency_key ||= SecureRandom.uuid
  end

  def render_blocked
    @editable = false
    @form_error = @shape.reasons.first || "This room inventory cannot be edited here."
    render :show, status: :unprocessable_entity
  end

  def inventory_path
    item_inventory_departure_arrangement_hotel_path(@departure, @supplier_arrangement, @arrangement_item)
  end

  def resource_params
    params.fetch(:resource, ActionController::Parameters.new).permit(:name, :maximum_occupancy)
  end

  def night_params
    params.fetch(:night, ActionController::Parameters.new).permit(:starts_on)
  end

  def opening_params
    params.fetch(:opening, ActionController::Parameters.new).permit(
      :proposed_opening_quantity, :evidence_kind, :evidence_on, :evidence_reference_note,
      :service_occurrence_id, :supplier_resource_id
    )
  end

  def opening_cell
    @shape.cells.find do |cell|
      cell.night_definition.service_occurrence_id == opening_params[:service_occurrence_id] &&
        cell.resource_definition.supplier_resource_id == opening_params[:supplier_resource_id]
    end
  end

  def opening_target
    [ opening_params[:service_occurrence_id], opening_params[:supplier_resource_id] ].join("--")
  end

  def night_name(date_string)
    Date.iso8601(date_string.to_s).strftime("%B %-d")
  rescue Date::Error, ArgumentError
    "Room night"
  end
end
