# frozen_string_literal: true

class ActivitySuccessorsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement

  def create
    CreateSupplierArrangementSuccessor.new(
      **activity_command_context, arrangement: @supplier_arrangement,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Successor draft created. The activity identity is unchanged."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end
end
