class ReinstateCapacity < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, release_event:, quantity:, projection_lock_version:, idempotency_key:, attributes:, recorded_at: nil, effective_on: nil, effective_sequence: nil)
    @agency = agency
    @actor = actor
    @release_event = release_event
    @quantity = quantity
    @projection_lock_version = projection_lock_version
    @idempotency_key = idempotency_key
    @attributes = attributes
    @recorded_at = recorded_at
    @effective_on = effective_on
    @effective_sequence = effective_sequence
  end

  def call
    release_event = @agency.capacity_events.find(@release_event.id)
    record_capacity_event!(
      pool: release_event.capacity_pool,
      event_type: "reinstated",
      quantity: @quantity,
      effective_on: @effective_on,
      effective_sequence: @effective_sequence,
      recorded_at: @recorded_at,
      projection_lock_version: @projection_lock_version,
      idempotency_key: @idempotency_key,
      attributes: @attributes,
      reinstates_event: release_event
    )
  end
end
