# frozen_string_literal: true

class ActivityFinalCountsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement

  def create
    item = @supplier_arrangement.arrangement_items.find(params[:arrangement_item_id])
    RecordActivityFinalCount.new(
      **activity_command_context, arrangement: @supplier_arrangement, item: item,
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Final participant count recorded."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end
end
