class EstablishCapacity < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, definition:, projection_lock_version:, idempotency_key:, recorded_at: nil, effective_on: nil, effective_sequence: nil)
    @agency = agency
    @actor = actor
    @definition = definition
    @projection_lock_version = projection_lock_version
    @idempotency_key = idempotency_key
    @recorded_at = recorded_at
    @effective_on = effective_on
    @effective_sequence = effective_sequence
  end

  def call
    definition = @agency.capacity_pool_definitions.find(@definition.id)
    quantity = definition.proposed_opening_quantity
    raise Error.new("Enter a proposed opening quantity before establishing capacity.", code: :invalid) if quantity.blank?

    # Omitted effective_on resolves to the local recorded date so opening supply
    # becomes effective at activation/recording time, not the Occurrence start.
    record_capacity_event!(
      pool: definition.capacity_pool,
      event_type: "established",
      quantity: quantity,
      effective_on: @effective_on,
      effective_sequence: @effective_sequence,
      recorded_at: @recorded_at,
      projection_lock_version: @projection_lock_version,
      idempotency_key: @idempotency_key,
      attributes: {
        evidence_kind: definition.evidence_kind,
        evidence_on: definition.evidence_on,
        evidence_reference_note: definition.evidence_reference_note,
        evidence_external_reference: definition.evidence_external_reference,
        override: definition.override?,
        override_reason: definition.override_reason
      }
    )
  end
end
