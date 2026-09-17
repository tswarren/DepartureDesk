class CapacityReconciliationsController < ApplicationController
  include EffectiveCapacityAccess

  before_action :require_departure_management!
  before_action :set_effective_capacity_context

  def create
    result = ReconcileCapacityPool.new(
      agency: Current.agency,
      actor: Current.agency_user,
      pool: @capacity_pool,
      observed_quantity: reconciliation_params[:observed_quantity],
      observed_at: reconciliation_params[:observed_at],
      projection_lock_version: params[:projection_lock_version],
      idempotency_key: params[:idempotency_key],
      attributes: capacity_evidence_params(reconciliation_params)
    ).call
    redirect_to departure_arrangement_capacity_pool_path(
      @departure, @supplier_arrangement, @capacity_pool
    ), notice: result.status == :replayed ? "Reconciliation already recorded." : "Reconciliation recorded."
  rescue AgencyCommand::Error => error
    @capacity_reconciliation = CapacityReconciliation.new(
      reconciliation_params.slice(
        :observed_quantity,
        :observed_at,
        :evidence_kind,
        :evidence_on,
        :evidence_reference_note,
        :evidence_external_reference,
        :override,
        :override_reason
      )
    )
    @submitted_capacity_reconciliation = reconciliation_params
    @reconciliation_idempotency_key = params[:idempotency_key]
    add_effective_capacity_error(@capacity_reconciliation, error)
    render_effective_capacity
  end

  private

  def reconciliation_params
    @reconciliation_params ||= params.fetch(
      :capacity_reconciliation, ActionController::Parameters.new
    ).permit(
      :observed_quantity,
      :observed_at,
      :evidence_kind,
      :evidence_on,
      :evidence_reference_note,
      :evidence_external_reference,
      :override,
      :override_reason
    )
  end
end
