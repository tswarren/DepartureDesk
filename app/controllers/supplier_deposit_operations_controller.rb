# frozen_string_literal: true

class SupplierDepositOperationsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def attest
    commitment = @supplier_arrangement.supplier_commitments.find(params[:commitment_id])
    AttestSupplierDepositHandledExternally.new(
      agency: Current.agency,
      actor: Current.agency_user,
      commitment:,
      note: params[:note],
      confirmed_complete: params[:confirmed_complete],
      idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid
    ).call
    redirect_after_deposit_operation notice: "Deposit confirmed handled outside DepartureDesk."
  rescue AgencyCommand::Error => error
    redirect_after_deposit_operation alert: error.message
  end

  def record_milestone
    version = @supplier_arrangement.governing_version ||
      @supplier_arrangement.versions.order(:version_number).last
    raise ActiveRecord::RecordNotFound if version.nil?

    RecordSupplierPlanningMilestone.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version:,
      kind: params[:kind].presence || "names_assigned_to_supplier",
      occurred_on: params[:occurred_on],
      occurred_at: params[:occurred_at],
      note: params[:note],
      idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid
    ).call
    redirect_after_deposit_operation notice: "Planning milestone recorded."
  rescue AgencyCommand::Error => error
    redirect_after_deposit_operation alert: error.message
  end

  private

  def redirect_after_deposit_operation(**flash)
    if params[:return_to].to_s == CompileCruiseDepositsAndDeadlinesWorkspace::RETURN_TOKEN
      redirect_to departure_arrangement_cruise_deposits_and_deadlines_path(
        @departure, @supplier_arrangement
      ), **flash
    else
      redirect_to departure_arrangement_path(@departure, @supplier_arrangement), **flash
    end
  end
end
