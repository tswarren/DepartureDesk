# frozen_string_literal: true

class ActivityItemsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement
  before_action :set_activity_version

  def create
    save(nil)
  end

  def update
    item = @supplier_arrangement.arrangement_items.find(params[:id])
    save(item)
  end

  private

  def save(item)
    SaveActivity.new(
      **activity_command_context, departure: @departure, arrangement: @supplier_arrangement,
      item: item, attributes: activity_params, idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Activity saved."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end

  def activity_params
    params.fetch(:activity, ActionController::Parameters.new).permit(
      :name, :location, :starts_on, :starts_at_local, :ends_at_local, :time_zone,
      :participant_spaces, :rate_amount, :expected_persons, :minimum_quantity, :terms_on,
      :inclusion_wording, :cancellation_wording
    )
  end
end
