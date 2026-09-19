# frozen_string_literal: true

class SupplierCommitmentEvidenceCoveragesController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_coverage

  def new_revoke
    @dependents = @coverage.current_dependent_commitments
    @idempotency_key = SecureRandom.uuid
  end

  def revoke
    RevokeSupplierCommitmentEvidenceCoverage.new(
      agency: Current.agency,
      actor: Current.agency_user,
      coverage: @coverage,
      reason: params[:reason],
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_commitments_path(@departure, @supplier_arrangement),
      notice: "Evidence coverage revoked."
  rescue AgencyCommand::Error => error
    @dependents = @coverage.current_dependent_commitments
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    flash.now[:alert] = error.message
    render :new_revoke, status: :unprocessable_entity
  end

  private

  def set_coverage
    @coverage = @supplier_arrangement.supplier_commitment_evidence_coverages.find(params[:id])
  end
end
