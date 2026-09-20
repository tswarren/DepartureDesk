# frozen_string_literal: true

class SupplierArrangementEndingsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_departure
  before_action :set_supplier_arrangement

  def show
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
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    flash.now[:alert] = error.message
    @preview = nil
    @evaluation = nil
    @payload = { "blockers" => [], "cascades" => [], "reason_choices" => EvaluateSupplierArrangementEnding::ENDING_REASONS }
    render :show, status: :unprocessable_entity
  end
end
