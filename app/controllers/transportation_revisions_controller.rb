# frozen_string_literal: true

class TransportationRevisionsController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_transportation_arrangement

  def create
    ReviseConfirmedSupplierArrangementVersion.new(
      **transportation_command_context,
      arrangement: @supplier_arrangement,
      reason: params[:reason],
      idempotency_key: params[:idempotency_key],
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      vertical: "ground_transportation"
    ).call
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      notice: "Confirmed draft revised."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      alert: error.message
  end
end
