# frozen_string_literal: true

class TransportationConfirmationsController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_transportation_arrangement
  before_action :set_transportation_version

  def create
    RecordTransportationSupplierConfirmation.new(
      **transportation_command_context,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      idempotency_key: params[:idempotency_key],
      evidence_attributes: confirmation_params,
      identifier_attributes: identifier_params
    ).call
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      notice: "Supplier confirmed."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      alert: error.message
  end

  private

  def confirmation_params
    params.fetch(:confirmation, ActionController::Parameters.new).permit(
      :evidence_kind, :evidence_on, :channel, :reference_note, :confirmed_without_identifier_reason
    )
  end

  def identifier_params
    params.fetch(:identifier, ActionController::Parameters.new).permit(:kind, :value, :label)
  end
end
