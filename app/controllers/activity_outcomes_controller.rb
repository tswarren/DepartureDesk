# frozen_string_literal: true

class ActivityOutcomesController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement

  def create
    item = @supplier_arrangement.arrangement_items.find(params[:arrangement_item_id])
    RecordActivityOperatingOutcome.new(
      **activity_command_context, arrangement: @supplier_arrangement, item: item,
      outcome: params[:outcome], evidence: params[:evidence], occurred_on: params[:occurred_on],
      observed_quantity: params[:observed_quantity], idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Supplier decision recorded."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end
end
