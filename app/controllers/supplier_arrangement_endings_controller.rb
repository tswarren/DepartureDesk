# frozen_string_literal: true

class SupplierArrangementEndingsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
    load_preview_from_params
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    @preview = nil
    @evaluation = nil
    @raw_token = nil
    @payload = {
      "blockers" => [],
      "cascades" => [],
      "reason_choices" => EvaluateSupplierArrangementEnding::ENDING_REASONS
    }
    render :show, status: :unprocessable_entity
  end

  def create
    result = EndSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      preview_token: params[:preview_token],
      idempotency_key: params[:idempotency_key].presence || SecureRandom.uuid,
      selected_cascade_keys: Array(params[:selected_cascade_keys]),
      ending_reason: params[:ending_reason],
      ending_reason_label: params[:ending_reason_label],
      ending_reason_note: params[:ending_reason_note],
      replacement_arrangement_id: params[:replacement_arrangement_id],
      required_acknowledgments: Array(params[:required_acknowledgments]),
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version]
    ).call

    notice = result.status == :replayed ? "Arrangement ending already recorded." : "Arrangement ended."
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement), notice:
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if error.code == :conflict
      redirect_to end_departure_arrangement_path(@departure, @supplier_arrangement),
        alert: error.message
      return
    end

    flash.now[:alert] = error.message
    load_preview_from_params
    render :show, status: :unprocessable_entity
  end

  private

  def load_preview_from_params
    selected = Array(params[:selected_cascade_keys]).presence
    result = PreviewEndSupplierArrangement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      selected_cascade_keys: selected,
      ending_reason: params[:ending_reason],
      ending_reason_label: params[:ending_reason_label],
      ending_reason_note: params[:ending_reason_note],
      replacement_arrangement_id: params[:replacement_arrangement_id],
      required_acknowledgments: Array(params[:required_acknowledgments])
    ).call

    @preview = result.record
    @raw_token = result.raw_token
    @evaluation = result.evaluation
    @payload = @preview.payload
  end
end
