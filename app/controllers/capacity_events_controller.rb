class CapacityEventsController < ApplicationController
  include EffectiveCapacityAccess

  COMMANDS = {
    "increased" => IncreaseCapacity,
    "released" => ReleaseCapacity,
    "reinstated" => ReinstateCapacity,
    "withdrawn" => WithdrawCapacity,
    "corrected_up" => CorrectCapacityUp,
    "corrected_down" => CorrectCapacityDown
  }.freeze

  before_action :require_departure_management!
  before_action :set_effective_capacity_context

  def create
    command_class = COMMANDS[event_params[:event_type]]
    raise ActiveRecord::RecordNotFound if command_class.nil?

    result = command_class.new(**command_arguments(command_class)).call
    redirect_to departure_arrangement_capacity_pool_path(
      @departure, @supplier_arrangement, @capacity_pool
    ), notice: result.status == :replayed ? "Capacity event already recorded." : "Capacity event recorded."
  rescue AgencyCommand::Error => error
    @capacity_event = CapacityEvent.new(event_form_attributes)
    @submitted_capacity_event = event_params
    @event_idempotency_key = params[:idempotency_key]
    add_effective_capacity_error(@capacity_event, error)
    render_effective_capacity
  end

  private

  def event_params
    @event_params ||= params.fetch(:capacity_event, ActionController::Parameters.new).permit(
      :event_type,
      :quantity,
      :effective_on,
      :effective_sequence,
      :release_event_id,
      :corrects_event_id,
      :capacity_reconciliation_id,
      :evidence_kind,
      :evidence_on,
      :evidence_reference_note,
      :evidence_external_reference,
      :override,
      :override_reason,
      :resolution_note
    )
  end

  def command_arguments(command_class)
    common = {
      agency: Current.agency,
      actor: Current.agency_user,
      projection_lock_version: params[:projection_lock_version],
      idempotency_key: params[:idempotency_key],
      quantity: event_params[:quantity],
      effective_on: event_params[:effective_on],
      effective_sequence: event_params[:effective_sequence],
      attributes: capacity_evidence_params(event_params)
    }

    if command_class == ReinstateCapacity
      common.merge(
        release_event: @capacity_pool.capacity_events.find(event_params[:release_event_id])
      )
    elsif command_class == CorrectCapacityUp || command_class == CorrectCapacityDown
      common.merge(
        pool: @capacity_pool,
        corrects_event_id: event_params[:corrects_event_id],
        capacity_reconciliation_id: event_params[:capacity_reconciliation_id]
      )
    else
      common.merge(pool: @capacity_pool)
    end
  end

  def event_form_attributes
    event_params.slice(
      :event_type,
      :quantity,
      :effective_on,
      :effective_sequence,
      :corrects_event_id,
      :capacity_reconciliation_id,
      :evidence_kind,
      :evidence_on,
      :evidence_reference_note,
      :evidence_external_reference,
      :override,
      :override_reason
    )
  end
end
