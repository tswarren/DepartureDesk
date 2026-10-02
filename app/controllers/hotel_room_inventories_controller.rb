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
      version = reload_authorized_version!
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

  def update
    return render_blocked if @shape.blocked? || !@editable

    @submitted_quantities = submitted_quantities
    @submitted_evidence = evidence_params.to_h.with_indifferent_access
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    changes = inventory_changes
    if changes.nil?
      render :show, status: :unprocessable_entity
      return
    end

    ActiveRecord::Base.transaction do
      apply_inventory_changes!(changes)
    end
    redirect_to inventory_path, notice: "Room inventory saved."
  rescue AgencyCommand::Error => error
    hotel_command_error(error, :show)
  end

  private

  def prepare_inventory
    assign_hotel_shape
    @editable = hotel_editable? && !@shape.blocked?
    @resource_attributes ||= { name: nil, maximum_occupancy: 4 }
    @idempotency_key ||= SecureRandom.uuid
  end

  def render_blocked
    @editable = false
    @form_error = @shape.reasons.first || "This room inventory cannot be edited here."
    render :show, status: :unprocessable_entity
  end

  def inventory_path
    default_path = item_inventory_departure_arrangement_hotel_path(@departure, @supplier_arrangement, @arrangement_item)
    path_after_hotel_edit(default_path)
  end

  def resource_params
    params.fetch(:resource, ActionController::Parameters.new).permit(:name, :maximum_occupancy)
  end

  def submitted_quantities
    params.fetch(:quantity, ActionController::Parameters.new).to_unsafe_h.each_with_object({}) do |(resource_id, dates), result|
      next unless dates.respond_to?(:each)

      result[resource_id.to_s] = dates.each_with_object({}) do |(date, value), by_date|
        by_date[date.to_s] = value
      end
    end
  end

  def evidence_params
    params.fetch(:evidence, ActionController::Parameters.new).permit(
      :evidence_kind, :evidence_on, :evidence_reference_note
    )
  end

  def inventory_changes
    creates = []
    updates = []
    @invalid_cells = []
    return nil unless submitted_pool_locks_current?

    @submitted_quantities.each do |resource_id, dates|
      dates.each do |date, raw|
        cell = category_for_resource(resource_id)&.cells&.find { |row| row.date.to_date.iso8601 == date }
        key = "#{resource_id}--#{date}"
        if cell.nil? || !category_for(cell)&.supported? || !cell.supported?
          @form_error ||= cell&.reason || category_for(cell)&.reason || "This contracted room count cannot be saved here."
          @invalid_cells << key
          next
        end

        value = raw.to_s.strip
        if value.blank?
          if cell.pool_definition
            @form_error ||= "Enter a valid room count."
            @invalid_cells << key
          end
          next
        end

        quantity = parsed_room_count(value, key)
        next if quantity.nil?

        if cell.pool_definition
          next if cell.pool_definition.proposed_opening_quantity == quantity

          updates << { cell: cell, quantity: quantity }
        else
          creates << { cell: cell, quantity: quantity }
        end
      end
    end
    return nil if @invalid_cells.any?

    if creates.any? && !evidence_complete?
      @form_error = "Enter complete supplier evidence."
      return nil
    end

    { creates: creates, updates: updates }
  end

  def submitted_pool_locks_current?
    current = true
    @submitted_quantities.each do |resource_id, dates|
      dates.each_key do |date|
        cell = category_for_resource(resource_id)&.cells&.find { |row| row.date.to_date.iso8601 == date }
        next if cell.nil? || !category_for(cell)&.supported? || !cell.supported?

        pool = cell.pool_definition
        next if pool.nil?

        submitted_lock = params.dig(:pool_lock, pool.id)
        next if submitted_lock.present? && submitted_lock.to_i == pool.lock_version

        @form_error ||= "Room inventory changed while you were editing it."
        @invalid_cells << "#{resource_id}--#{date}"
        current = false
      end
    end
    current
  end

  def parsed_room_count(value, key)
    quantity = Integer(value, 10)
    unless quantity.positive?
      @form_error ||= "Proposed opening quantity must be greater than zero."
      @invalid_cells << key
      return nil
    end

    quantity
  rescue ArgumentError, TypeError
    @form_error ||= "Proposed opening quantity must be a whole number."
    @invalid_cells << key
    nil
  end

  def evidence_complete?
    @submitted_evidence[:evidence_kind].present? &&
      @submitted_evidence[:evidence_on].present? &&
      @submitted_evidence[:evidence_reference_note].present?
  end

  def apply_inventory_changes!(changes)
    occurrences = {}
    changes[:creates].group_by { |change| change[:cell].date }.sort.each do |date, group|
      version = reload_authorized_version!
      occurrence = group.filter_map { |change| change[:cell].night_definition&.service_occurrence }.first
      occurrence ||= occurrences[date]
      occurrence ||= CreateServiceOccurrence.new(
        **hotel_command_context,
        item: @arrangement_item,
        version_lock_version: version.lock_version,
        idempotency_key: "#{@idempotency_key}:night:#{date.to_date.iso8601}",
        attributes: {
          name: night_name(date),
          starts_on: date,
          ends_on: date,
          time_zone: @departure.time_zone
        }
      ).call.record
      occurrences[date] = occurrence
      group.each do |change|
        version = reload_authorized_version!
        cell = change[:cell]
        ConfigureCapacityPairWithPool.new(
          **hotel_command_context,
          item: @arrangement_item,
          service_occurrence: occurrence,
          supplier_resource: cell.resource_definition.supplier_resource,
          version_lock_version: version.lock_version,
          idempotency_key: "#{@idempotency_key}:opening:#{cell.resource_definition.supplier_resource_id}:#{date.to_date.iso8601}",
          pool_attributes: {
            label: "#{night_name(date)} #{cell.resource_definition.name}",
            inventory_mode: "block",
            measurement_basis: "resource_units",
            unit_label: "rooms",
            proposed_opening_quantity: change[:quantity],
            evidence_kind: @submitted_evidence[:evidence_kind],
            evidence_on: @submitted_evidence[:evidence_on],
            evidence_reference_note: @submitted_evidence[:evidence_reference_note]
          }
        ).call
      end
    end

    changes[:updates].each do |change|
      pool = change[:cell].pool_definition
      UpdateCapacityPool.new(
        **hotel_command_context,
        definition: pool,
        lock_version: params.dig(:pool_lock, pool.id),
        attributes: { proposed_opening_quantity: change[:quantity] }
      ).call
      sync_hotel_rate_usage_quantity!(change[:cell], change[:quantity])
    end
  end

  def sync_hotel_rate_usage_quantity!(cell, quantity)
    version = @supplier_arrangement_version.reload
    assumption = version.supplier_cost_usage_assumptions.find_by(
      arrangement_item_id: @arrangement_item.id,
      service_occurrence_id: cell.night_definition.service_occurrence_id,
      supplier_resource_id: cell.resource_definition.supplier_resource_id
    )
    return if assumption.nil?

    profiles = assumption.supplier_cost_occupancy_profiles.order(:position, :id).to_a
    return unless profiles.one?
    profile = profiles.first
    return unless profile.label == "Contracted rooms"
    return if profile.resource_unit_count == quantity

    UpdateSupplierCostOccupancyProfile.new(
      **hotel_command_context,
      profile: profile,
      lock_version: profile.lock_version,
      attributes: {
        label: profile.label,
        resource_unit_count: quantity
      }
    ).call
  end

  def category_for(cell)
    return if cell.nil?

    category_for_resource(cell.resource_definition.supplier_resource_id)
  end

  def category_for_resource(resource_id)
    @shape.categories.find { |category| category.resource_definition.supplier_resource_id == resource_id.to_s }
  end

  def night_name(date)
    date.to_date.strftime("%B %-d")
  rescue Date::Error, ArgumentError
    "Room night"
  end
end
