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
    load_recorded_activation if @review.activated?
    @idempotency_key = SecureRandom.uuid
    prepare_review_form
  end

  def create
    @review = compile_review
    @idempotency_key = params[:idempotency_key]
    prepare_review_form
    if forged_evidence_policy?
      refuse_cruise_post("That confirmation evidence policy cannot be selected.")
      return
    end

    command = cruise_activation_command
    if (replay = command.replay_if_recorded)
      redirect_to departure_arrangement_cruise_activation_path(@departure, @supplier_arrangement),
        notice: "Cruise supplier arrangement was already activated."
      return
    end

    unless post_allowed?
      refuse_cruise_post("This Cruise review cannot activate these terms. Use Advanced Supplier planning.")
      return
    end

    if @review.elapsed.any? && !elapsed_review_matches?
      params.delete(:elapsed_deadlines_acknowledged)
      refuse_cruise_post(elapsed_review_message)
      return
    end

    result = command.call
    redirect_to departure_arrangement_cruise_activation_path(@departure, @supplier_arrangement),
      notice: result.status == :replayed ? "Cruise supplier arrangement was already activated." : "Cruise supplier arrangement activated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    @review = compile_review
    prepare_review_form
    @idempotency_key = params[:idempotency_key]
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_message(:base, error.message)
    render :show, status: :unprocessable_entity
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @review = compile_review
    prepare_review_form
    @idempotency_key = params[:idempotency_key]
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_command_error(error)
    render :show, status: :unprocessable_entity
  end

  private

  def load_recorded_activation
    @activation = SupplierArrangementActivation.includes(
      :actor, supplier_confirmation: :supplier_issued_identifiers
    ).find_by(
      agency: Current.agency,
      supplier_arrangement_version: @supplier_arrangement_version
    )
  end

  def compile_review
    CompileCruiseActivationReview.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version
    ).call
  end

  def post_allowed?
    @review.activation_confirmable?
  end

  def cruise_activation_command
    ConfirmAndActivateCruiseGroup.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      arrangement_lock_version: params[:arrangement_lock_version],
      version_lock_version: params[:version_lock_version],
      idempotency_key: params[:idempotency_key],
      terms_acknowledged: params[:terms_acknowledged],
      existing_confirmation_id: reuse_confirmation_id,
      evidence_attributes: new_proof? ? confirmation_params : {},
      supplier_reference: new_proof? ? params[:supplier_reference] : nil,
      opening_overrides: opening_override_params,
      elapsed_deadlines_acknowledged: elapsed_acknowledged?,
      confirmed_quantities: keyed_commitment_params(:confirmed_quantities),
      confirmed_amounts_minor_units: keyed_commitment_params(:confirmed_amounts_minor_units),
      duplicate_acknowledgement_token: params[:duplicate_acknowledgement_token],
      forged_evidence_policy: forged_evidence_policy?
    )
  end

  def forged_evidence_policy?
    params.key?(:allow_relaxed_confirmation) || params.key?(:evidence_policy)
  end

  def new_proof?
    return false if params[:proof_choice] == "reuse"
    return true if params[:proof_choice] == "new"
    return true if confirmation_params[:evidence_kind].present?

    @existing_confirmations.blank?
  end

  def reuse_confirmation_id
    return if new_proof?

    params[:existing_confirmation_id]
  end

  def opening_override_params
    raw = params[:opening_overrides]
    return {} if raw.blank?
    return raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)

    raw.to_h
  end

  def prepare_review_form
    load_confirmation_choices
    assign_elapsed_review_token
  end

  def assign_elapsed_review_token
    return if @review.elapsed.empty?

    @elapsed_review_token = CruiseElapsedReviewToken.issue(
      agency_id: Current.agency.id,
      arrangement_version_id: @supplier_arrangement_version.id,
      elapsed_definition_ids: @review.elapsed.map(&:definition_id)
    )
  end

  def elapsed_review_matches?
    payload = CruiseElapsedReviewToken.read(params[:elapsed_review_token])
    return false if payload.blank?

    payload["agency_id"].to_s == Current.agency.id.to_s &&
      payload["arrangement_version_id"].to_s == @supplier_arrangement_version.id.to_s &&
      Array(payload["elapsed_definition_ids"]).map(&:to_s).sort == current_elapsed_definition_ids
  end

  def elapsed_review_message
    payload = CruiseElapsedReviewToken.read(params[:elapsed_review_token])
    reviewed_this_version = payload.present? &&
      payload["agency_id"].to_s == Current.agency.id.to_s &&
      payload["arrangement_version_id"].to_s == @supplier_arrangement_version.id.to_s
    if reviewed_this_version
      "A Supplier requirement elapsed after this review was opened. Review it before activating."
    else
      "This elapsed acknowledgment does not match the requirements on this review."
    end
  end

  def current_elapsed_definition_ids
    @review.elapsed.map { |row| row.definition_id.to_s }.sort
  end

  def elapsed_acknowledged?
    @review.elapsed.any? &&
      params[:elapsed_deadlines_acknowledged] == "1" &&
      elapsed_review_matches?
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
      :evidence_kind, :other_evidence_label, :evidence_on, :channel, :reference_note
    )
  end
end
