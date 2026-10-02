# frozen_string_literal: true

class TransportationSegmentsController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :ensure_composable_departure!
  before_action :set_transportation_arrangement
  before_action :set_transportation_version
  before_action :assign_transportation_workspace
  before_action :set_transportation_item, only: %i[edit update]

  def new
    @attributes = segment_defaults
    @idempotency_key = SecureRandom.uuid
  end

  def create
    save_segment(item: nil)
  end

  def edit
    @attributes = existing_attributes
    @idempotency_key = SecureRandom.uuid
  end

  def update
    save_segment(item: @arrangement_item)
  end

  private

  def save_segment(item:)
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    @attributes = segment_params.to_h
    SaveTransportationSegment.new(
      **transportation_command_context,
      departure: @departure,
      arrangement: @supplier_arrangement,
      item:,
      attributes: @attributes,
      idempotency_key: @idempotency_key
    ).call
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      notice: "Transportation segment saved."
  rescue AgencyCommand::Error => error
    flash.now[:alert] = error.message
    render(item ? :edit : :new, status: :unprocessable_entity)
  end

  def segment_defaults
    {
      time_zone: @departure.time_zone,
      confirmed_motorcoaches: 1,
      additional_motorcoaches: 2,
      maximum_occupancy: 15
    }
  end

  def existing_attributes
    version = @supplier_arrangement_version
    occurrence = version.service_occurrence_definitions.find_by!(arrangement_item: @arrangement_item)
    resource = version.supplier_resource_definitions.find_by!(arrangement_item: @arrangement_item)
    pool = version.capacity_pool_definitions.find_by(arrangement_item: @arrangement_item)
    component = version.supplier_cost_components.joins(supplier_cost_definition: :supplier_cost_source)
      .find_by(supplier_cost_sources: { arrangement_item_id: @arrangement_item.id })
    deadline = version.supplier_deadline_definitions.joins(:supplier_deadline_definition_coverage_links)
      .find_by(supplier_deadline_definition_coverage_links: { arrangement_item_id: @arrangement_item.id })
    {
      name: @arrangement_item_definition.name,
      origin_name: occurrence.origin_name,
      destination_name: occurrence.destination_name,
      starts_on: occurrence.starts_on,
      ends_on: occurrence.ends_on,
      starts_at_local: occurrence.starts_at_local&.strftime("%H:%M"),
      ends_at_local: occurrence.ends_at_local&.strftime("%H:%M"),
      time_zone: occurrence.time_zone,
      maximum_occupancy: resource.maximum_occupancy,
      confirmed_motorcoaches: pool&.proposed_opening_quantity,
      maximum_total_resource_units: pool&.maximum_total_resource_units,
      rate_amount: component && Money.new(component.amount_minor_units, @departure.operating_currency).format(symbol: false, thousands_separator: false),
      final_count_on: deadline && deadline.rule_parameters["date"]
    }
  end

  def segment_params
    params.fetch(:segment, ActionController::Parameters.new).permit(
      :name, :origin_name, :destination_name, :starts_on, :ends_on,
      :starts_at_local, :ends_at_local, :time_zone, :maximum_occupancy,
      :confirmed_motorcoaches, :additional_motorcoaches, :maximum_total_resource_units,
      :rate_amount, :final_count_on
    )
  end
end
