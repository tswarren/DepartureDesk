require "test_helper"

class RefreshCapacityProjectionJobTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other_agency = agencies(:cove)
    @actor = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "M3B Projection Child")
    @contractor = create_capacity_supplier(@agency, "M3B Child Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Child Provider")
    @recorded_at = Time.zone.parse("2026-06-01 12:00:00 UTC")
  end

  test "child job refreshes due projection and duplicate delivery is safe" do
    graph = graph_with_future_increase("duplicate-child")
    due_at = graph[:projection].reload.next_applies_at

    travel_to due_at + 1.minute do
      RefreshCapacityProjectionJob.perform_now(agency_id: @agency.id, capacity_pool_id: graph[:pool].id)
      RefreshCapacityProjectionJob.perform_now(agency_id: @agency.id, capacity_pool_id: graph[:pool].id)
    end

    assert_equal 10, graph[:projection].reload.current_supplier_capacity
    assert_nil graph[:projection].next_applies_at
    assert_equal 2, graph[:pool].capacity_events.count
  end

  test "missing and other-agency pools are no-ops" do
    graph = graph_with_future_increase("missing-child")
    due_at = graph[:projection].reload.next_applies_at

    travel_to due_at + 1.minute do
      assert_no_changes -> { graph[:projection].reload.current_supplier_capacity } do
        RefreshCapacityProjectionJob.perform_now(agency_id: SecureRandom.uuid, capacity_pool_id: graph[:pool].id)
        RefreshCapacityProjectionJob.perform_now(agency_id: @other_agency.id, capacity_pool_id: graph[:pool].id)
        RefreshCapacityProjectionJob.perform_now(agency_id: @agency.id, capacity_pool_id: SecureRandom.uuid)
      end
    end
  end

  test "delayed job catches up every due event" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      effective_on: Date.new(2026, 6, 2),
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "catch-up-first",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call
    IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 3,
      effective_on: Date.new(2026, 6, 3),
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "catch-up-second",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call

    travel_to Time.find_zone!("America/New_York").local(2026, 6, 5) do
      RefreshCapacityProjectionJob.perform_now(agency_id: @agency.id, capacity_pool_id: graph[:pool].id)
    end

    assert_equal 13, graph[:projection].reload.current_supplier_capacity
    assert_nil graph[:projection].next_applies_at
  end

  private

  def graph_with_future_increase(idempotency_key)
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      effective_on: Date.new(2026, 6, 3),
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: idempotency_key,
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call
    graph
  end

  def ordinary_evidence
    {
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-06-01",
      evidence_reference_note: "Supplier confirmed capacity change"
    }
  end
end
