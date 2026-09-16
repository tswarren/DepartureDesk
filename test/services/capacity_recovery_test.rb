require "test_helper"

class CapacityRecoveryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "M3B Capacity Recovery")
    @contractor = create_capacity_supplier(@agency, "M3B Recovery Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Recovery Provider")
    @recorded_at = Time.zone.parse("2026-06-02 12:00:00 UTC")
  end

  test "find unresolved capacity dependencies returns nonzero pending and open discrepancy ids" do
    graph = unresolved_graph
    reconciliation = reconcile_open(graph)

    result = FindUnresolvedCapacityDependencies.new(
      agency: @agency,
      arrangement: graph[:arrangement],
      now: @recorded_at
    ).call

    assert_equal [ graph[:pool].id ], result.capacity_pool_ids
    assert_equal [ graph[:future_event].id ], result.pending_capacity_event_ids
    assert_equal [ reconciliation.id ], result.open_capacity_reconciliation_ids

    by_departure = FindUnresolvedCapacityDependencies.new(agency: @agency, departure: @departure, now: @recorded_at).call
    assert_includes by_departure.capacity_pool_ids, graph[:pool].id
    assert_includes by_departure.pending_capacity_event_ids, graph[:future_event].id
    assert_includes by_departure.open_capacity_reconciliation_ids, reconciliation.id
  end

  test "resolved reconciliations are not unresolved dependencies" do
    graph = unresolved_graph
    reconciliation = reconcile_open(graph)
    CorrectCapacityUp.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "recovery-resolve",
      capacity_reconciliation_id: reconciliation.id,
      recorded_at: @recorded_at,
      attributes: ordinary_evidence.merge(resolution_note: "Supplier discrepancy corrected.")
    ).call

    result = FindUnresolvedCapacityDependencies.new(
      agency: @agency,
      arrangement: graph[:arrangement],
      now: @recorded_at
    ).call

    assert_not_includes result.open_capacity_reconciliation_ids, reconciliation.id
  end

  test "force supplier inactivation reports capacity pools without mutating capacity" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)
    graph[:occurrence_definition].update!(
      starts_on: Date.current + 30.days,
      ends_on: Date.current + 31.days
    )
    event_count = graph[:pool].capacity_events.count
    projection_quantity = graph[:projection].reload.current_supplier_capacity

    result = ChangeSupplierStatus.new(
      agency: @agency,
      actor: @actor,
      supplier: @provider,
      status: "inactive",
      lock_version: @provider.lock_version,
      force: true,
      force_reason: "Proceed despite retained capacity."
    ).call

    assert_equal :updated, result.status
    assert_equal event_count, graph[:pool].capacity_events.count
    assert_equal projection_quantity, graph[:projection].reload.current_supplier_capacity
    audit = AuditEvent.where(action: "supplier.inactivated", subject_id: @provider.id).last
    assert_equal [ graph[:pool].id ], audit.details["affected_capacity_pool_ids"]
    assert_equal [ graph[:arrangement].id ], audit.details["affected_supplier_arrangement_ids"]
  end

  test "capacity command after supplier inactivation is rejected without changing projection" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)
    @provider.update!(status: "inactive")

    error = assert_raises(AgencyCommand::Error) do
      IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: graph[:projection].reload.lock_version,
        idempotency_key: "inactive-race-increase",
        recorded_at: @recorded_at,
        attributes: ordinary_evidence
      ).call
    end

    assert_equal :invalid_state, error.code
    assert_equal 8, graph[:projection].reload.current_supplier_capacity
  end

  private

  def unresolved_graph
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)
    result = IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      effective_on: Date.new(2026, 6, 3),
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "recovery-future-increase",
      recorded_at: @recorded_at - 1.day,
      attributes: ordinary_evidence
    ).call
    graph.merge(future_event: result.record)
  end

  def reconcile_open(graph)
    ReconcileCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      observed_quantity: 10,
      observed_at: @recorded_at,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "recovery-open",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call.record
  end

  def ordinary_evidence
    {
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-06-02",
      evidence_reference_note: "Supplier confirmed capacity state."
    }
  end
end
