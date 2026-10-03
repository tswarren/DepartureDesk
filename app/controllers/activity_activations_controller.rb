# frozen_string_literal: true

class ActivityActivationsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement
  before_action :set_activity_version

  def create
    ActivateActivityAgreement.new(
      **activity_command_context, arrangement: @supplier_arrangement, version: @supplier_arrangement_version,
      idempotency_key: params[:idempotency_key],
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Activity agreement activated."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end
end
