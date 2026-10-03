# frozen_string_literal: true

class ActivityRevisionsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement
  before_action :set_activity_version

  def create
    ReviseConfirmedSupplierArrangementVersion.new(
      **activity_command_context, arrangement: @supplier_arrangement,
      reason: params[:reason], idempotency_key: params[:idempotency_key],
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      vertical: "activity_attraction"
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Confirmed draft revised."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end
end
