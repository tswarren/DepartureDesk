# frozen_string_literal: true

class TransportationAmountDuesController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_transportation_arrangement

  def create
    SaveTransportationAmountDue.new(
      **transportation_command_context,
      arrangement: @supplier_arrangement,
      due_on: params[:due_on],
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      notice: "Charter amount due saved."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      alert: error.message
  end
end
