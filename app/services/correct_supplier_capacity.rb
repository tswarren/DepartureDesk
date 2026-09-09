class CorrectSupplierCapacity < SupplierCapacityCommand
  EVENT_TYPE = "correction"
  REQUIRES_ADMIN = true

  def initialize(
    agency:,
    resource:,
    service_occurrence:,
    reason:,
    idempotency_key:,
    effective_on: nil,
    agency_held_delta: 0,
    pending_request_delta: 0,
    guaranteed_delta: 0,
    consumed_delta: 0,
    released_current_delta: 0,
    corrected_event: nil,
    lock_version: nil,
    actor: nil,
    actor_identifier: nil,
    privileged: false
  )
    @correction_deltas = {
      "agency_held" => Integer(agency_held_delta || 0),
      "pending_request" => Integer(pending_request_delta || 0),
      "guaranteed" => Integer(guaranteed_delta || 0),
      "consumed" => Integer(consumed_delta || 0),
      "released_current" => Integer(released_current_delta || 0)
    }
    @corrected_event = corrected_event
    quantity = @correction_deltas.values.map(&:abs).sum
    super(
      agency:,
      resource:,
      service_occurrence:,
      quantity:,
      reason:,
      idempotency_key:,
      effective_on:,
      lock_version:,
      actor:,
      actor_identifier:,
      privileged:
    )
  rescue ArgumentError, TypeError
    raise Error.new("Capacity correction deltas must be whole numbers.", code: :invalid)
  end

  private

  def validate_basic_inputs!
    super
    raise Error.new("Capacity correction must include a compensating effect.", code: :invalid) if @correction_deltas.values.all?(&:zero?)
  end

  def event_deltas
    @correction_deltas
  end

  def event_extra_attributes
    { corrected_event: @corrected_event }
  end

  def same_event_material?(event)
    super && event.corrected_event_id == @corrected_event&.id
  end
end
