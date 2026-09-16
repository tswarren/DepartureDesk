require "test_helper"

class CapacityReconciliationCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "M3B Reconciliation")
    @contractor = create_capacity_supplier(@agency, "M3B Reconciliation Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Reconciliation Provider")
    @recorded_at = Time.zone.parse("2026-06-02 12:00:00 UTC")
  end

  test "reconcile records a matched immutable observation" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)

    result = ReconcileCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      observed_quantity: 8,
      observed_at: @recorded_at,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "reconcile-match",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call

    assert_equal :matched, result.status
    assert result.record.matched?
    assert_equal 0, result.record.variance
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_reconciled", subject_id: graph[:arrangement].id).count
  end

  test "reconcile is idempotent for the same observation" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)
    command_args = {
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      observed_quantity: 8,
      observed_at: @recorded_at,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "reconcile-replay",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    }

    created = ReconcileCapacityPool.new(**command_args).call
    replayed = ReconcileCapacityPool.new(**command_args.merge(projection_lock_version: 0)).call

    assert_equal :matched, replayed.status
    assert_equal created.record.id, replayed.record.id
    assert_equal 1, graph[:pool].capacity_reconciliations.count
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_reconciled", subject_id: graph[:arrangement].id).count
  end

  test "reconcile records an open discrepancy without changing projection" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)

    result = ReconcileCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      observed_quantity: 10,
      observed_at: @recorded_at,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "reconcile-open",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call

    assert_equal :open_discrepancy, result.status
    assert result.record.open_discrepancy?
    assert_equal 2, result.record.variance
    assert_equal 8, graph[:projection].reload.current_supplier_capacity
    assert_equal 1, graph[:pool].capacity_events.count
  end

  test "linked correction resolves a discrepancy and updates projection atomically" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)
    reconciliation = reconcile_open(graph, observed_quantity: 10, idempotency_key: "reconcile-resolve").record

    result = CorrectCapacityUp.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "resolve-up",
      capacity_reconciliation_id: reconciliation.id,
      recorded_at: @recorded_at + 1.hour,
      attributes: ordinary_evidence.merge(resolution_note: "Supplier discrepancy corrected.")
    ).call

    assert_equal :created, result.status
    assert reconciliation.reload.resolved?
    assert_equal 1, reconciliation.resolutions.count
    assert_equal 10, graph[:projection].reload.current_supplier_capacity
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_reconciliation_resolved", subject_id: graph[:arrangement].id).count
  end

  test "partial linked correction leaves discrepancy open" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at - 1.day)
    reconciliation = reconcile_open(graph, observed_quantity: 10, idempotency_key: "reconcile-partial").record

    CorrectCapacityUp.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 1,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "partial-up",
      capacity_reconciliation_id: reconciliation.id,
      recorded_at: @recorded_at + 1.hour,
      attributes: ordinary_evidence.merge(resolution_note: "Supplier discrepancy partially corrected.")
    ).call

    assert reconciliation.reload.open_discrepancy?
    assert_equal 1, reconciliation.resolution_quantity
    assert_equal 0, AuditEvent.where(action: "supplier_arrangement.capacity_reconciliation_resolved", subject_id: graph[:arrangement].id).count
  end

  private

  def reconcile_open(graph, observed_quantity:, idempotency_key:)
    ReconcileCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      observed_quantity: observed_quantity,
      observed_at: @recorded_at,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: idempotency_key,
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call
  end

  def ordinary_evidence
    {
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-06-02",
      evidence_reference_note: "Supplier confirmed counted capacity."
    }
  end
end
