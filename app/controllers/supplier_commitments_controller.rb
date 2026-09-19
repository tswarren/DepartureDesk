# frozen_string_literal: true

class SupplierCommitmentsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, except: :index
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_commitment, only: %i[new_reopen reopen]

  def index
    commitments = @supplier_arrangement.supplier_commitments
      .with_current_disposition_state
      .includes(:committed_supplier, :supplier_confirmation)
      .order(opened_at: :desc, id: :desc)
      .to_a
    @open_commitments = commitments.select(&:open_state?)
    @accepted_exceptions = commitments.select { |commitment| commitment.disposition_outcome == "waived" }
    @other_terminal = commitments.reject(&:open_state?).reject { |commitment| commitment.disposition_outcome == "waived" }
    @confirmations = @supplier_arrangement.supplier_confirmations.order(recorded_at: :desc, id: :desc)
  end

  def new_dispose
    @outcome = params[:outcome].presence_in(%w[satisfied released]) || "satisfied"
    @open_commitments = open_commitments_scope
    @confirmations = confirmation_scope_for_outcome(@outcome)
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
    @outcome = params[:outcome].presence_in(%w[satisfied released]) || "satisfied"
    @open_commitments = open_commitments_scope
    @confirmations = confirmation_scope_for_outcome(@outcome)
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

  private

  def set_commitment
    @commitment = @supplier_arrangement.supplier_commitments.find(params[:id])
  end

  def open_commitments_scope
    @supplier_arrangement.supplier_commitments
      .with_current_disposition_state
      .includes(:committed_supplier)
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
    confirmation_scope.where(evidence_kind: kinds)
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
