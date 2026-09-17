class AppendCapacityEventAlreadyLocked
  DIRECTIONS = CapacityTimelineReplay::DIRECTIONS.transform_values(&:sign).freeze

  def initialize(pool:, actor:, event_type:, quantity:, effective_on:, recorded_at:, evidence:)
    @pool = pool
    @actor = actor
    @event_type = event_type.to_s
    @quantity = quantity
    @effective_on = effective_on
    @recorded_at = recorded_at
    @evidence = evidence.to_h.with_indifferent_access
  end

  # Internal only. Caller must already hold Pool/projection locks and own the
  # enclosing confirmation audit/idempotency boundary.
  def call
    validate!
    sequence = next_sequence
    event = CapacityEvent.create!(
      agency_id: @pool.agency_id,
      departure_id: @pool.departure_id,
      supplier_arrangement_id: @pool.supplier_arrangement_id,
      supplier_arrangement_version_id: @pool.supplier_arrangement_version_id,
      arrangement_item_id: @pool.arrangement_item_id,
      service_occurrence_id: @pool.service_occurrence_id,
      supplier_resource_id: @pool.supplier_resource_id,
      capacity_pool_id: @pool.id,
      supplying_supplier_id: @pool.supplying_supplier_id,
      event_type: @event_type,
      quantity: @quantity,
      measurement_basis: @pool.measurement_basis,
      effective_on: @effective_on,
      effective_time_zone: @pool.effective_time_zone,
      applies_at: applies_at,
      effective_sequence: sequence,
      recorded_at: @recorded_at,
      actor: @actor,
      evidence_kind: @evidence[:evidence_kind],
      evidence_on: @evidence[:evidence_on],
      evidence_reference_note: @evidence[:evidence_reference_note],
      evidence_external_reference: @evidence[:evidence_external_reference],
      override: ActiveModel::Type::Boolean.new.cast(@evidence[:override]) || false,
      override_reason: @evidence[:override_reason]
    )
    catch_up!(event)
    event
  end

  private

  def validate!
    unless CapacityEvent::EVENT_TYPES.include?(@event_type) && @event_type != "established"
      raise AgencyCommand::Error.new("Choose a valid capacity consequence event type.", code: :invalid)
    end
    unless @pool.numeric_inventory? && @pool.capacity_events.where(event_type: "established").exists?
      raise AgencyCommand::Error.new("Capacity must be established before confirmation consequences.", code: :invalid_state)
    end
    unless @quantity.is_a?(Integer) && @quantity.positive?
      raise AgencyCommand::Error.new("Capacity consequence quantity must be a positive whole number.", code: :invalid)
    end
    raise AgencyCommand::Error.new("Capacity consequence effective date is required.", code: :invalid) if @effective_on.blank?
  end

  def next_sequence
    @pool.capacity_events.where(effective_on: @effective_on).maximum(:effective_sequence).to_i + 1
  end

  def applies_at
    zone = ActiveSupport::TimeZone[@pool.effective_time_zone] || Time.zone
    zone.local(@effective_on.year, @effective_on.month, @effective_on.day).beginning_of_day.utc
  end

  def catch_up!(event)
    projection = @pool.capacity_projection
    raise AgencyCommand::Error.new("Capacity projection is missing.", code: :conflict) if projection.nil?

    projection.lock!
    now = @recorded_at
    if event.applies_at <= now
      projection.current_supplier_capacity =
        projection.current_supplier_capacity + DIRECTIONS.fetch(event.event_type) * event.quantity
      projection.last_event = event
      projection.last_effective_on = event.effective_on
      projection.last_effective_sequence = event.effective_sequence
      projection.last_recorded_at = event.recorded_at
    end
    next_event = @pool.capacity_events.where("applies_at > ?", now)
      .order(:applies_at, :effective_on, :effective_sequence, :recorded_at, :id).first
    projection.next_event = next_event
    projection.next_applies_at = next_event&.applies_at
    projection.rebuilt_at = now
    projection.save!
  end
end
