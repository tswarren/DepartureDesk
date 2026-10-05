# frozen_string_literal: true

class ActivityConfirmationsController < ApplicationController
  include ActivityArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_activity_arrangement
  before_action :set_activity_version

  def create
    RecordActivitySupplierConfirmation.new(
      **activity_command_context, arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version, idempotency_key: params[:idempotency_key],
      evidence_attributes: params.fetch(:confirmation, {}).permit(
        :evidence_kind, :evidence_on, :channel, :reference_note, :confirmed_without_identifier_reason
      )
    ).call
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement),
      notice: "Supplier confirmed the Activity agreement."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_activity_path(@departure, @supplier_arrangement), alert: error.message
  end
end
