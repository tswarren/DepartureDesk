# frozen_string_literal: true

class TransportationFinalCountsController < ApplicationController
  include TransportationArrangementAccess

  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_transportation_arrangement

  def create
    version = @supplier_arrangement.governing_version || @supplier_arrangement_version_from_confirmation
    confirmation = @supplier_arrangement.supplier_confirmations.order(recorded_at: :desc).first
    commitments = SupplierCommitment.with_current_disposition_state.where(
      supplier_arrangement: @supplier_arrangement,
      supplier_arrangement_version: version,
      opening_kind: "deadline_requirement"
    ).select(&:open_state?)
    raise AgencyCommand::Error.new("There is no open final-count commitment to complete.", code: :invalid_state) if commitments.empty?

    DisposeSupplierCommitmentsWithEvidence.new(
      **transportation_command_context,
      arrangement: @supplier_arrangement,
      confirmation:,
      commitment_ids: commitments.map(&:id),
      outcome: "satisfied",
      idempotency_key: params[:idempotency_key]
    ).call
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      notice: "Final passenger and luggage count recorded."
  rescue AgencyCommand::Error => error
    redirect_to departure_arrangement_transportation_path(@departure, @supplier_arrangement),
      alert: error.message
  end

  private

  def supplier_arrangement_version_from_confirmation
    @supplier_arrangement.versions.find_by(status: "activated")
  end
end
