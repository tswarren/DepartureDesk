# frozen_string_literal: true

class CruiseActivationsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, only: :create
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_editable_draft_version

  def show
    @review = compile_review
    @idempotency_key = SecureRandom.uuid
    load_confirmation_choices
  end

  def create
    @review = compile_review
    @idempotency_key = params[:idempotency_key]
    load_confirmation_choices
    unless post_allowed?
      refuse_cruise_post("This Cruise review cannot activate these terms. Use Advanced Supplier planning.")
      return
    end

    unless elapsed_set_unchanged?
      refuse_cruise_post("A Supplier requirement elapsed after this review was opened. Review it before activating.")
      return
    end

    result = ActivateSupplierArrangementVersion.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key],
      existing_confirmation_id: params[:existing_confirmation_id],
      evidence_attributes: confirmation_params,
      identifier_attributes: identifier_params.presence,
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: elapsed_acknowledged?,
      confirmed_quantities: keyed_commitment_params(:confirmed_quantities),
      confirmed_amounts_minor_units: keyed_commitment_params(:confirmed_amounts_minor_units),
      duplicate_acknowledgement_token: params[:duplicate_acknowledgement_token]
    ).call
    redirect_to departure_arrangement_cruise_activation_path(@departure, @supplier_arrangement),
      notice: result.status == :replayed ? "Cruise supplier arrangement was already activated." : "Cruise supplier arrangement activated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @review = compile_review
    load_confirmation_choices
    @idempotency_key = params[:idempotency_key]
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_message(:base, error.message)
    render :show, status: :unprocessable_entity
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @review = compile_review
    load_confirmation_choices
    @idempotency_key = params[:idempotency_key]
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_command_error(error)
    render :show, status: :unprocessable_entity
  end

  private

  def compile_review
    CompileCruiseActivationReview.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version
    ).call
  end

  def post_allowed?
    @review.cruise_post_allowed? &&
      @review.cost_sources_completely_represented? &&
      @review.triggers_completely_represented?
  end

  def elapsed_set_unchanged?
    shown = Array(params[:elapsed_definition_ids]).map(&:to_s).sort
    current = @review.elapsed.map { |row| row.definition_id.to_s }.sort
    shown == current
  end

  def elapsed_acknowledged?
    @review.elapsed.any? && params[:elapsed_deadlines_acknowledged] == "1"
  end

  def refuse_cruise_post(message)
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_message(:base, message)
    render :show, status: :unprocessable_entity
  end

  def load_confirmation_choices
    @existing_confirmations = @supplier_arrangement_version.supplier_confirmations
      .where(confirming_supplier_id: @supplier_arrangement.contracting_supplier_id)
      .order(recorded_at: :desc, id: :desc)
  end

  def keyed_commitment_params(key)
    raw = params[key]
    return {} if raw.blank?
    return raw.to_h unless raw.respond_to?(:permit)

    allowed = @supplier_arrangement_version.supplier_commitment_trigger_definitions
      .pluck(:id)
      .flat_map { |id| [ id.to_s, id ] }
    raw.permit(*allowed).to_h
  end

  def confirmation_params
    params.fetch(:confirmation, ActionController::Parameters.new).permit(
      :evidence_kind, :other_evidence_label, :evidence_on, :channel,
      :reference_note, :confirmed_without_identifier_reason
    )
  end

  def identifier_params
    raw = params.fetch(:identifier, ActionController::Parameters.new).permit(
      :identifier_type, :other_type_label, :issuer_context, :display_value
    )
    return nil if raw.to_h.values.all?(&:blank?)

    raw
  end
end
