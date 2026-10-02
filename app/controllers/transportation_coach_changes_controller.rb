# frozen_string_literal: true

class TransportationCoachChangesController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_transportation_arrangement

  def create
    item = @supplier_arrangement.arrangement_items.find(params[:arrangement_item_id])
    version = @supplier_arrangement.governing_version
    pool = version.capacity_pool_definitions.find_by!(arrangement_item: item).capacity_pool
    RecordTransportationCoachChange.new(
      **transportation_command_context,
      arrangement: @supplier_arrangement,
      item:,
      quantity: params[:quantity],
      effective_on: params[:effective_on],
      event_type: params[:event_type],
      idempotency_key: params[:idempotency_key],
      projection_lock_version: pool.capacity_projection.lock_version,
      evidence_attributes: {
        evidence_kind: params[:evidence_kind],
        evidence_on: params[:evidence_on],
        evidence_reference_note: params[:evidence_reference_note]
      }
    ).call
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      notice: "Motorcoach change recorded."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      alert: error.message
  end
end
