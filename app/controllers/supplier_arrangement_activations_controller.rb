class SupplierArrangementActivationsController < ApplicationController
  include SupplierArrangementAccess

  before_action :require_departure_view!
  before_action :require_departure_management!, only: :create
  before_action :set_departure
  before_action :set_supplier_arrangement
  before_action :set_editable_draft_version

  def show
    load_preview
    @idempotency_key = SecureRandom.uuid
  end

  def create
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
      cost_source_coverage_acknowledged: params[:cost_source_coverage_acknowledged],
      provisional_costs_acknowledged: params[:provisional_costs_acknowledged],
      commitment_trigger_coverage_acknowledged: params[:commitment_trigger_coverage_acknowledged],
      elapsed_deadlines_acknowledged: params[:elapsed_deadlines_acknowledged],
      confirmed_quantities: keyed_commitment_params(:confirmed_quantities),
      confirmed_amounts_minor_units: keyed_commitment_params(:confirmed_amounts_minor_units),
      duplicate_acknowledgement_token: params[:duplicate_acknowledgement_token]
    ).call
    redirect_to departure_arrangement_path(@departure, @supplier_arrangement),
      notice: result.status == :replayed ? "Arrangement was already activated." : "Arrangement activated."
  rescue AgencyCommand::DuplicateReviewRequired => error
    load_preview
    @idempotency_key = params[:idempotency_key]
    @acknowledgement_token = error.token
    @duplicate_candidates = error.candidates
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_message(:base, error.message)
    if params.dig(:identifier, :display_value).present?
      @command_form.add_message(:display_value, error.message)
    end
    render :show, status: :unprocessable_entity
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    load_preview
    @idempotency_key = params[:idempotency_key]
    @command_form = CommandForm.new(param_key: "confirmation")
    @command_form.add_command_error(error)
    if error.message.to_s.downcase.include?("identifier")
      @command_form.add_message(:display_value, error.message)
    end
    render :show, status: :unprocessable_entity
  end

  private

  def keyed_commitment_params(key)
    raw = params[key]
    return {} if raw.blank?
    return raw.to_h unless raw.respond_to?(:permit)

    allowed = @supplier_arrangement_version.supplier_commitment_trigger_definitions
      .pluck(:id)
      .flat_map { |id| [ id.to_s, id ] }
    raw.permit(*allowed).to_h
  end

  def load_preview
    @readiness = SupplierArrangementActivationReadiness.new(
      agency: Current.agency,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version
    ).call
    @provisional_selections = @readiness.cost_selections.select do |_source, definition|
      definition.estimate?
    end
    @capacity_definitions = @supplier_arrangement_version.capacity_pool_definitions
      .includes(capacity_pool: [ :supplying_supplier, :capacity_events ]).order(:position, :id)
    @triggers = @supplier_arrangement_version.supplier_commitment_trigger_definitions
      .includes(:committed_supplier).order(:position, :id)
    @elapsed_deadlines = MaterializeSupplierDeadlineDefinitionsAlreadyLocked.new(
      agency: Current.agency,
      actor: Current.agency_user,
      arrangement: @supplier_arrangement,
      version: @supplier_arrangement_version,
      activation: nil,
      departure: @departure
    ).preview_elapsed
    @existing_confirmations = @supplier_arrangement_version.supplier_confirmations
      .where(confirming_supplier_id: @supplier_arrangement.contracting_supplier_id)
      .order(recorded_at: :desc, id: :desc)
  end

  def confirmation_params
    params.fetch(:confirmation, ActionController::Parameters.new).permit(
      :evidence_kind, :other_evidence_label, :evidence_on, :channel,
      :reference_note, :confirmed_without_identifier_reason
    )
  end

  def identifier_params
    params.fetch(:identifier, ActionController::Parameters.new).permit(
      :identifier_type, :other_type_label, :issuer_context, :display_value
    )
  end
end
