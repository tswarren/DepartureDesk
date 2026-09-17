require "test_helper"

class RefreshDueCapacityProjectionsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "M3B Projection Sweep")
    @contractor = create_capacity_supplier(@agency, "M3B Sweep Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Sweep Provider")
    @recorded_at = Time.zone.parse("2026-06-01 12:00:00 UTC")
  end

  test "sweep enqueues due capacity projection child jobs and does not refresh inline" do
    graph = due_capacity_graph(idempotency_key: "sweep-due-one")
    due_at = graph[:projection].reload.next_applies_at

    travel_to due_at + 1.minute do
      assert_enqueued_with job: RefreshCapacityProjectionJob, args: [ { agency_id: @agency.id, capacity_pool_id: graph[:pool].id } ] do
        RefreshDueCapacityProjectionsJob.perform_now
      end
    end

    assert_equal 8, graph[:projection].reload.current_supplier_capacity
  end

  test "sweep pages with a keyset of at most 100" do
    assert_equal 100, RefreshDueCapacityProjectionsJob::BATCH_SIZE
    stub_const(RefreshDueCapacityProjectionsJob, :BATCH_SIZE, 1) do
      graphs = 3.times.map { |index| due_capacity_graph(prefix: "Sweep Batch #{index}", idempotency_key: "sweep-batch-#{index}") }
      due_at = graphs.map { |graph| graph[:projection].reload.next_applies_at }.max

      travel_to due_at + 1.minute do
        assert_enqueued_jobs 3, only: RefreshCapacityProjectionJob do
          RefreshDueCapacityProjectionsJob.perform_now
        end
      end
    end
  end

  test "recurring configuration and worker recognize the capacity queue" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    %w[development production].each do |env|
      task = recurring.fetch(env).fetch("refresh_due_capacity_projections")
      assert_equal "RefreshDueCapacityProjectionsJob", task.fetch("class")
      assert_equal "capacity", task.fetch("queue")
      assert_equal "every hour", task.fetch("schedule")
    end

    assert_equal :capacity, RefreshDueCapacityProjectionsJob.new.queue_name.to_sym
    assert_equal :capacity, RefreshCapacityProjectionJob.new.queue_name.to_sym
  end

  private

  def due_capacity_graph(prefix: "Sweep", idempotency_key:)
    graph = build_activated_established_capacity_graph(
      prefix: prefix,
      recorded_at: @recorded_at
    )
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
