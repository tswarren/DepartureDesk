class ReconcileCapacityPool < AgencyCommand
  include CapacityCommandSupport

  def initialize(agency:, actor:, pool:, observed_quantity:, observed_at:, projection_lock_version:, idempotency_key:, attributes:, recorded_at: nil)
    @agency = agency
    @actor = actor
    @pool = pool
    @observed_quantity = observed_quantity
    @observed_at = observed_at
    @projection_lock_version = projection_lock_version
    @idempotency_key = idempotency_key
    @attributes = attributes.to_h.with_indifferent_access
    @recorded_at = recorded_at
  end

  def call
    ensure_arrangement_actor!
    observed_quantity = normalize_observed_capacity_quantity(@observed_quantity)
    observed_at = normalize_observed_at(@observed_at)
    recorded_at = normalize_recorded_at(@recorded_at)
    evidence_attrs = normalize_capacity_event_evidence_or_override(@attributes)

    ActiveRecord::Base.transaction do
      lock_authorized_arrangement_agency!
      departure, arrangement, version, item, occurrence, resource, _supplier, locked_pool = lock_capacity_event_graph!(@pool)
      ensure_activated_capacity_graph!(departure, arrangement, version)
      ensure_numeric_capacity_pool!(locked_pool)
      ensure_capacity_pool_established!(locked_pool)

      projection = locked_pool.capacity_projection
      raise Error.new("Capacity projection is missing.", code: :invalid_state) if projection.nil?

      projection.lock!
      refresh_capacity_projection_state!(locked_pool, projection, recorded_at)

      ledger_quantity = ledger_quantity_at(locked_pool, observed_at)
      reconciliation = locked_pool.capacity_reconciliations.build(
        agency: @agency,
        departure: departure,
        supplier_arrangement: arrangement,
        supplier_arrangement_version: version,
        arrangement_item: item,
        service_occurrence: occurrence,
        supplier_resource: resource,
        observed_quantity: observed_quantity,
        observed_at: observed_at,
        observed_time_zone: locked_pool.effective_time_zone,
        ledger_quantity: ledger_quantity,
        variance: observed_quantity - ledger_quantity,
        actor: @actor,
        recorded_at: recorded_at,
        **evidence_attrs
      )
      payload = {
        capacity_pool_id: locked_pool.id,
        observed_quantity: observed_quantity,
        observed_at: observed_at,
        recorded_at: recorded_at,
        evidence: evidence_attrs
      }

      idempotent_capacity_reconciliation!(
        command_name: self.class.name,
        idempotency_key: @idempotency_key,
        payload: payload,
        reconciliation: reconciliation
      ) do
        ensure_current_lock_version!(projection, @projection_lock_version)
        reconciliation.save!
        audit_capacity_reconciled!(arrangement, reconciliation)
      end
    end
  rescue ActiveRecord::RecordInvalid => error
    command_error_from(error)
  end

  private

  def normalize_observed_at(value)
    normalize_recorded_at(value)
  rescue AgencyCommand::Error
    raise AgencyCommand::Error.new("Observed at is not a valid time.", code: :invalid)
  end

  def ledger_quantity_at(pool, observed_at)
    events = pool.capacity_events.order(:effective_on, :effective_sequence, :recorded_at, :id).to_a
    CapacityTimelineReplay.new(events).call
    events.select { |event| event.applies_at <= observed_at }
      .sum { |event| CapacityTimelineReplay::DIRECTIONS.fetch(event.event_type).sign * event.quantity }
  end

  def audit_capacity_reconciled!(arrangement, reconciliation)
    audit!(
      agency: @agency,
      action: "supplier_arrangement.capacity_reconciled",
      subject: arrangement,
      actor: @actor,
      details: {
        "supplier_arrangement_id" => arrangement.id,
        "supplier_arrangement_version_id" => reconciliation.supplier_arrangement_version_id,
        "arrangement_item_id" => reconciliation.arrangement_item_id,
        "capacity_pool_id" => reconciliation.capacity_pool_id,
        "capacity_reconciliation_id" => reconciliation.id,
        "observed_quantity" => reconciliation.observed_quantity,
        "ledger_quantity" => reconciliation.ledger_quantity,
        "variance" => reconciliation.variance,
        "status" => reconciliation.status
      }
    )
  end
end
