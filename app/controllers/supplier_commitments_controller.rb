# frozen_string_literal: true

class SupplierCommitmentsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :index
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_commitment, only: %i[new_reopen reopen new_disqualify disqualify]

  def index
    commitments = @supplier_arrangement.supplier_commitments
      .with_current_disposition_state
      .includes(
        :committed_supplier,
        :supplier_confirmation,
        { supplier_commitment_dispositions: [ :supplier_commitment_reopening, :supplier_commitment_evidence_coverage ] }
      )
      .order(opened_at: :desc, id: :desc)
      .to_a
    @open_commitments = commitments.select(&:open_state?)
    @accepted_exceptions = commitments.select { |commitment| commitment.disposition_outcome == "waived" }
    @other_terminal = commitments.reject(&:open_state?).reject { |commitment| commitment.disposition_outcome == "waived" }
    @confirmations = @supplier_arrangement.supplier_confirmations.order(recorded_at: :desc, id: :desc)
    @evidence_coverages = @supplier_arrangement.supplier_commitment_evidence_coverages
      .includes(:supplier_confirmation, :supplier_commitment_evidence_coverage_revocation, members: :supplier_commitment)
      .order(recorded_at: :desc, id: :desc)
  end

  def new_dispose
    prepare_dispose_form!
    @idempotency_key = SecureRandom.uuid
  end

  def dispose
    confirmation = confirmation_scope.find(params.require(:supplier_confirmation_id))
    DisposeSupplierCommitmentsWithEvidence.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      confirmation:,
      commitment_ids: Array(params[:supplier_commitment_ids]),
      outcome: params.require(:outcome),
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_commitments_path(@departure, @supplier_arrangement),
      notice: "Commitment disposition recorded."
  rescue AgencyCommand::Error => error
    prepare_dispose_form!
    @selected_commitment_ids = Array(params[:supplier_commitment_ids]).map(&:to_s)
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    flash.now[:alert] = error.message
    render :new_dispose, status: :unprocessable_entity
  end

  def new_waive
    @open_commitments = open_commitments_scope
    @idempotency_key = SecureRandom.uuid
  end

  def waive
    unless Current.agency_user.permitted?(:override_supplier_planning_terms)
      raise AgencyCommand::Error.new(AgencyCommand::UNAUTHORIZED, code: :unauthorized)
    end

    commitment = find_open_commitment!(params.require(:supplier_commitment_id))
    WaiveSupplierCommitment.new(
      agency: Current.agency,
      actor: Current.agency_user,
      commitment:,
      reason: params[:reason],
      accepted_risk_acknowledged: params[:accepted_risk_acknowledged],
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_commitments_path(@departure, @supplier_arrangement),
      notice: "Commitment waived."
  rescue AgencyCommand::Error => error
    @open_commitments = open_commitments_scope
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    flash.now[:alert] = error.message
    render :new_waive, status: :unprocessable_entity
  end

  def new_reopen
    @disposition = @commitment.current_disposition
    raise ActiveRecord::RecordNotFound unless @disposition

    @idempotency_key = SecureRandom.uuid
  end

  def reopen
    disposition = @commitment.supplier_commitment_dispositions.find(params.require(:supplier_commitment_disposition_id))
    ReopenSupplierCommitment.new(
      agency: Current.agency,
      actor: Current.agency_user,
      commitment: @commitment,
      disposition:,
      reason: params[:reason],
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_commitments_path(@departure, @supplier_arrangement),
      notice: "Commitment reopened."
  rescue AgencyCommand::Error => error
    @disposition = @commitment.current_disposition
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    flash.now[:alert] = error.message
    render :new_reopen, status: :unprocessable_entity
  end

  def new_disqualify
    @disposition = @commitment.current_disposition
    raise ActiveRecord::RecordNotFound unless @disposition&.supplier_commitment_evidence_coverage_id

    @coverage = @disposition.supplier_commitment_evidence_coverage
    raise ActiveRecord::RecordNotFound if @coverage.blank? || @coverage.revoked?

    @idempotency_key = SecureRandom.uuid
  end

  def disqualify
    coverage = @supplier_arrangement.supplier_commitment_evidence_coverages
      .find(params.require(:supplier_commitment_evidence_coverage_id))
    DisqualifySupplierCommitmentFromEvidenceCoverage.new(
      agency: Current.agency,
      actor: Current.agency_user,
      coverage:,
      commitment: @commitment,
      disposition_id: params.require(:supplier_commitment_disposition_id),
      reason: params[:reason],
      idempotency_key: params.require(:idempotency_key)
    ).call
    redirect_to departure_arrangement_commitments_path(@departure, @supplier_arrangement),
      notice: "Commitment disqualified from evidence coverage."
  rescue AgencyCommand::Error => error
    @disposition = @commitment.supplier_commitment_dispositions.find_by(id: params[:supplier_commitment_disposition_id]) ||
      @commitment.current_disposition
    @coverage = @supplier_arrangement.supplier_commitment_evidence_coverages
      .find_by(id: params[:supplier_commitment_evidence_coverage_id]) ||
      @disposition&.supplier_commitment_evidence_coverage
    @idempotency_key = params[:idempotency_key].presence || SecureRandom.uuid
    flash.now[:alert] = error.message
    render :new_disqualify, status: :unprocessable_entity
  end

  private

  def set_commitment
    @commitment = @supplier_arrangement.supplier_commitments.find(params[:id])
  end

  def prepare_dispose_form!
    @outcome = params[:outcome].presence_in(%w[satisfied released]) || "satisfied"
    @confirmations = confirmation_scope_for_outcome(@outcome)
    @selected_confirmation_id = params[:supplier_confirmation_id].presence
    @selected_confirmation = @confirmations.find_by(id: @selected_confirmation_id)
    all_open = open_commitments_scope
    if @selected_confirmation
      @open_commitments = compatible_open_commitments(all_open, @selected_confirmation, @outcome)
      @selected_commitment_ids = selected_or_preselected_commitment_ids(@open_commitments)
    else
      @open_commitments = []
      @selected_commitment_ids = []
    end
  end

  def open_commitments_scope
    @supplier_arrangement.supplier_commitments
      .with_current_disposition_state
      .includes(:committed_supplier, :supplier_confirmation)
      .order(:opened_at, :id)
      .to_a
      .select(&:open_state?)
  end

  def confirmation_scope_for_outcome(outcome)
    kinds = if outcome == "released"
      SupplierConfirmation::RELEASE_EVIDENCE_KINDS
    else
      SupplierConfirmation::BOOKING_EVIDENCE_KINDS
    end
    confirmation_scope.includes(:confirming_supplier).where(evidence_kind: kinds)
  end

  def compatible_open_commitments(commitments, confirmation, outcome)
    kinds = if outcome == "released"
      DisposeSupplierCommitmentsWithEvidence::RELEASE_EVIDENCE_KINDS
    else
      DisposeSupplierCommitmentsWithEvidence::SATISFACTION_EVIDENCE_KINDS
    end
    return [] unless kinds.include?(confirmation.evidence_kind)

    commitments.select do |commitment|
      confirmation.agency_id == commitment.agency_id &&
        confirmation.departure_id == commitment.departure_id &&
        confirmation.supplier_arrangement_id == commitment.supplier_arrangement_id &&
        confirmation.supplier_arrangement_version_id == commitment.supplier_arrangement_version_id &&
        confirmation.confirming_supplier_id == commitment.committed_supplier_id &&
        commitment.supplier_confirmation_id != confirmation.id
    end
  end

  def selected_or_preselected_commitment_ids(open_commitments)
    submitted = Array(params[:supplier_commitment_ids]).map(&:to_s).presence
    return submitted if submitted

    open_commitments.map { |commitment| commitment.id.to_s }
  end

  def find_open_commitment!(id)
    commitment = @supplier_arrangement.supplier_commitments.find(id)
    raise AgencyCommand::Error.new("That commitment is no longer open.", code: :invalid_state) unless commitment.open_state?

    commitment
  end

  def confirmation_scope
    @supplier_arrangement.supplier_confirmations.order(recorded_at: :desc, id: :desc)
  end
end
