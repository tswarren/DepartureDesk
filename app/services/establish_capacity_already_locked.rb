class EstablishCapacityAlreadyLocked
  def initialize(definition:, actor:, recorded_at:)
    @definition = definition
    @pool = definition.capacity_pool
    @actor = actor
    @recorded_at = recorded_at
  end

  # Internal operation only. The enclosing activation command owns the complete
  # graph lock and the composite audit/idempotency boundary.
  def call
    validate!
    effective_on = @recorded_at.in_time_zone(@pool.effective_time_zone).to_date
    event = CapacityEvent.create!(
      agency_id: @definition.agency_id,
      departure_id: @definition.departure_id,
      supplier_arrangement_id: @definition.supplier_arrangement_id,
      supplier_arrangement_version_id: @definition.supplier_arrangement_version_id,
      arrangement_item_id: @definition.arrangement_item_id,
      service_occurrence_id: @definition.service_occurrence_id,
      supplier_resource_id: @definition.supplier_resource_id,
      capacity_pool_id: @pool.id,
      supplying_supplier_id: @pool.supplying_supplier_id,
      event_type: "established",
      quantity: @definition.proposed_opening_quantity,
      measurement_basis: @pool.measurement_basis,
      effective_on: effective_on,
      effective_time_zone: @pool.effective_time_zone,
      applies_at: @recorded_at,
      effective_sequence: 1,
      recorded_at: @recorded_at,
      evidence_kind: @definition.evidence_kind,
      evidence_on: @definition.evidence_on,
      evidence_reference_note: @definition.evidence_reference_note,
      evidence_external_reference: @definition.evidence_external_reference,
      override: @definition.override?,
      override_reason: @definition.override_reason,
      actor: @actor
    )
    CapacityProjection.create!(
      agency_id: @definition.agency_id,
      departure_id: @definition.departure_id,
      supplier_arrangement_id: @definition.supplier_arrangement_id,
      arrangement_item_id: @definition.arrangement_item_id,
      service_occurrence_id: @definition.service_occurrence_id,
      supplier_resource_id: @definition.supplier_resource_id,
      capacity_pool_id: @pool.id,
      current_supplier_capacity: event.quantity,
      last_event: event,
      last_effective_on: event.effective_on,
      last_effective_sequence: event.effective_sequence,
      last_recorded_at: event.recorded_at,
      rebuilt_at: @recorded_at
    )
    event
  end

  private

  def validate!
    unless @pool.numeric_inventory? &&
        @definition.proposed_opening_quantity.to_i.positive? &&
        !@pool.capacity_events.exists? &&
        @pool.capacity_projection.nil?
      raise AgencyCommand::Error.new(
        "Capacity establishment is no longer valid.", code: :conflict
      )
    end
  end
end
