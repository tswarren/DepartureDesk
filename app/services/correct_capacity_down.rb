class CorrectCapacityDown < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, pool:, quantity:, projection_lock_version:, idempotency_key:, attributes:, recorded_at: nil, effective_on: nil, effective_sequence: nil, corrects_event_id: nil, capacity_reconciliation_id: nil)
    @agency = agency
    @actor = actor
    @pool = pool
    @quantity = quantity
    @projection_lock_version = projection_lock_version
    @idempotency_key = idempotency_key
    @attributes = attributes
    @recorded_at = recorded_at
    @effective_on = effective_on
    @effective_sequence = effective_sequence
    @corrects_event_id = corrects_event_id
    @capacity_reconciliation_id = capacity_reconciliation_id
  end

  def call
    record_capacity_event!(
      pool: @pool,
      event_type: "corrected_down",
      quantity: @quantity,
      effective_on: @effective_on,
      effective_sequence: @effective_sequence,
      recorded_at: @recorded_at,
      projection_lock_version: @projection_lock_version,
      idempotency_key: @idempotency_key,
      attributes: @attributes,
      corrects_event_id: @corrects_event_id,
      capacity_reconciliation_id: @capacity_reconciliation_id
    )
  end
end
