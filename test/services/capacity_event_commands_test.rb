require "test_helper"

class CapacityEventCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M3B Event Capacity")
    @contractor = create_capacity_supplier(@agency, "M3B Event Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Event Provider")
    @recorded_at = Time.zone.parse("2026-06-01 12:00:00 UTC")
  end

  test "establish creates event and projection from activated graph" do
    graph = build_activated_unestablished_capacity_graph

    result = EstablishCapacity.new(
      agency: @agency,
      actor: @actor,
      definition: graph[:pool_definition],
      projection_lock_version: 0,
      idempotency_key: "establish-opening",
      recorded_at: @recorded_at
    ).call

    assert_equal :created, result.status
    event = result.record
    assert_equal "established", event.event_type
    assert_equal 8, event.quantity
    assert_equal graph[:version].id, event.supplier_arrangement_version_id
    projection = graph[:pool].reload.capacity_projection
    assert_equal 8, projection.current_supplier_capacity
    assert_equal event.id, projection.last_event_id
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_event_recorded", subject_id: graph[:arrangement].id).count
  end

  test "same day immediate increase updates projection quantity" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)

    result = IncreaseCapacity.new(
      agency: @agency,
      actor: @staff,
      pool: graph[:pool],
      quantity: 3,
      projection_lock_version: graph[:projection].lock_version,
      idempotency_key: "same-day-increase",
      recorded_at: @recorded_at + 1.hour,
      attributes: ordinary_evidence
    ).call

    assert_equal :created, result.status
    assert_equal "increased", result.record.event_type
    assert_equal 11, graph[:projection].reload.current_supplier_capacity
    assert_nil graph[:projection].next_applies_at
  end

  test "future event does not change current quantity until applies at" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    future_on = Date.new(2026, 6, 3)

    result = IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      effective_on: future_on,
      projection_lock_version: graph[:projection].lock_version,
      idempotency_key: "future-increase",
      recorded_at: @recorded_at,
      attributes: ordinary_evidence
    ).call

    event = result.record
    assert_equal 8, graph[:projection].reload.current_supplier_capacity
    assert_equal event.id, graph[:projection].next_event_id
    assert_equal Time.find_zone!("America/New_York").local(2026, 6, 4), event.applies_at

    RefreshDueCapacityProjection.new(
      agency: @agency,
      pool: graph[:pool],
      now: event.applies_at + 1.minute
    ).call
    assert_equal 10, graph[:projection].reload.current_supplier_capacity
  end

  test "negative timeline is rejected before commit" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)

    error = assert_raises(AgencyCommand::Error) do
      ReleaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 9,
        effective_on: Date.new(2026, 6, 1),
        projection_lock_version: graph[:projection].lock_version,
        idempotency_key: "too-much-release",
        recorded_at: @recorded_at + 1.hour,
        attributes: ordinary_evidence
      ).call
    end

    assert_equal :invalid_state, error.code
    assert_equal 1, graph[:pool].capacity_events.count
    assert_equal 8, graph[:projection].reload.current_supplier_capacity
  end

  test "override requires override supplier planning terms permission" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)

    error = assert_raises(AgencyCommand::Error) do
      IncreaseCapacity.new(
        agency: @agency,
        actor: @staff,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: graph[:projection].lock_version,
        idempotency_key: "staff-override",
        recorded_at: @recorded_at + 1.hour,
        attributes: {
          override: true,
          override_reason: "Supplier terms allow administrator exception."
        }
      ).call
    end
    assert_equal :unauthorized, error.code

    result = IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 1,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "admin-override",
      recorded_at: @recorded_at + 2.hours,
      attributes: {
        override: true,
        override_reason: "Supplier terms allow administrator exception."
      }
    ).call
    assert result.record.override?
    assert_equal 9, graph[:projection].reload.current_supplier_capacity
  end

  test "nonnumeric pool rejects events" do
    graph = build_activated_unestablished_capacity_graph(
      inventory_mode: "on_request",
      quantity: nil
    )

    error = assert_raises(AgencyCommand::Error) do
      IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: 0,
        idempotency_key: "nonnumeric-increase",
        recorded_at: @recorded_at,
        attributes: ordinary_evidence
      ).call
    end

    assert_equal :invalid_state, error.code
    assert_nil graph[:pool].reload.capacity_projection
    assert_empty graph[:pool].capacity_events
  end

  test "establish idempotency replays before stale projection lock" do
    graph = build_activated_unestablished_capacity_graph

    created = EstablishCapacity.new(
      agency: @agency,
      actor: @actor,
      definition: graph[:pool_definition],
      projection_lock_version: 0,
      idempotency_key: "establish-replay",
      recorded_at: @recorded_at
    ).call
    assert_equal :created, created.status

    replayed = EstablishCapacity.new(
      agency: @agency,
      actor: @actor,
      definition: graph[:pool_definition],
      projection_lock_version: 0,
      idempotency_key: "establish-replay",
      recorded_at: @recorded_at
    ).call

    assert_equal :replayed, replayed.status
    assert_equal created.record.id, replayed.record.id
    assert_equal 1, graph[:pool].capacity_events.count
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_event_recorded", subject_id: graph[:arrangement].id).count
  end

  test "event and reconcile idempotency replays when recorded_at is omitted" do
    travel_to @recorded_at do
      graph = build_activated_unestablished_capacity_graph

      established = EstablishCapacity.new(
        agency: @agency,
        actor: @actor,
        definition: graph[:pool_definition],
        projection_lock_version: 0,
        idempotency_key: "omit-recorded-establish"
      ).call
      assert_equal :created, established.status

      replayed_establish = EstablishCapacity.new(
        agency: @agency,
        actor: @actor,
        definition: graph[:pool_definition],
        projection_lock_version: 0,
        idempotency_key: "omit-recorded-establish"
      ).call
      assert_equal :replayed, replayed_establish.status
      assert_equal established.record.id, replayed_establish.record.id

      increased = IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: graph[:pool].reload.capacity_projection.lock_version,
        idempotency_key: "omit-recorded-increase",
        attributes: ordinary_evidence
      ).call
      replayed_increase = IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: 0,
        idempotency_key: "omit-recorded-increase",
        attributes: ordinary_evidence
      ).call
      assert_equal :replayed, replayed_increase.status
      assert_equal increased.record.id, replayed_increase.record.id

      observed_at = @recorded_at + 2.hours
      observed_quantity = graph[:pool].capacity_projection.reload.current_supplier_capacity
      reconciled = ReconcileCapacityPool.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        observed_quantity: observed_quantity,
        observed_at: observed_at,
        projection_lock_version: graph[:pool].capacity_projection.lock_version,
        idempotency_key: "omit-recorded-reconcile",
        attributes: ordinary_evidence
      ).call
      replayed_reconcile = ReconcileCapacityPool.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        observed_quantity: observed_quantity,
        observed_at: observed_at,
        projection_lock_version: 0,
        idempotency_key: "omit-recorded-reconcile",
        attributes: ordinary_evidence
      ).call
      assert_equal :matched, replayed_reconcile.status
      assert_equal reconciled.record.id, replayed_reconcile.record.id
    end
  end

  test "multi release reinstatement is atomic under one idempotency key and audit" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    first_release = ReleaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "release-one",
      recorded_at: @recorded_at + 1.hour,
      attributes: ordinary_evidence
    ).call.record
    second_release = ReleaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 3,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "release-two",
      recorded_at: @recorded_at + 2.hours,
      attributes: ordinary_evidence
    ).call.record

    result = ReinstateCapacity.new(
      agency: @agency,
      actor: @actor,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "multi-reinstate",
      recorded_at: @recorded_at + 3.hours,
      attributes: ordinary_evidence,
      releases: [
        { release_event: first_release, quantity: 2 },
        { release_event: second_release, quantity: 1 }
      ]
    ).call

    events = Array(result.record)
    assert_equal :created, result.status
    assert_equal 2, events.size
    assert_equal [ first_release.id, second_release.id ], events.map(&:reinstates_event_id)
    assert_equal 8 - 2 - 3 + 2 + 1, graph[:projection].reload.current_supplier_capacity

    audit = AuditEvent.where(action: "supplier_arrangement.capacity_event_recorded", subject_id: graph[:arrangement].id).order(:created_at).last
    assert_equal events.map(&:id), audit.details["capacity_event_ids"]

    replayed = ReinstateCapacity.new(
      agency: @agency,
      actor: @actor,
      projection_lock_version: 0,
      idempotency_key: "multi-reinstate",
      recorded_at: @recorded_at + 3.hours,
      attributes: ordinary_evidence,
      releases: [
        { release_event: first_release, quantity: 2 },
        { release_event: second_release, quantity: 1 }
      ]
    ).call
    assert_equal :replayed, replayed.status
    assert_equal events.map(&:id), Array(replayed.record).map(&:id)
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_event_recorded", subject_id: graph[:arrangement].id)
      .select { |event| event.details["capacity_event_ids"] == events.map(&:id) }
      .count
  end

  test "inactive supplier corrected up requires override path" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    @provider.update!(status: "inactive")

    error = assert_raises(AgencyCommand::Error) do
      CorrectCapacityUp.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: graph[:projection].reload.lock_version,
        idempotency_key: "inactive-up-evidence",
        recorded_at: @recorded_at + 1.hour,
        attributes: ordinary_evidence.merge(corrects_event_id: graph[:established_event].id)
      ).call
    end
    assert_equal :invalid_state, error.code

    result = CorrectCapacityUp.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 1,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "inactive-up-override",
      recorded_at: @recorded_at + 1.hour,
      attributes: {
        override: true,
        override_reason: "Preserve historical truth after forced inactivation.",
        corrects_event_id: graph[:established_event].id
      }
    ).call
    assert result.record.override?
    assert_equal 9, graph[:projection].reload.current_supplier_capacity
  end

  test "establish defaults effective on to recorded local date and rejects backdated increase before it" do
    graph = build_activated_unestablished_capacity_graph
    recorded_at = Time.zone.parse("2026-03-15 18:00:00 UTC")

    established = EstablishCapacity.new(
      agency: @agency,
      actor: @actor,
      definition: graph[:pool_definition],
      projection_lock_version: 0,
      idempotency_key: "establish-local-date",
      recorded_at: recorded_at
    ).call.record

    assert_equal Date.new(2026, 3, 15), established.effective_on
    assert_equal 8, graph[:pool].reload.capacity_projection.current_supplier_capacity

    error = assert_raises(AgencyCommand::Error) do
      IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        effective_on: Date.new(2026, 3, 1),
        projection_lock_version: graph[:pool].capacity_projection.lock_version,
        idempotency_key: "backdated-before-establish",
        recorded_at: recorded_at + 1.hour,
        attributes: ordinary_evidence
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  test "aggregate reinstate cannot exceed one release remainder" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    release = ReleaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 5,
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "release-five",
      recorded_at: @recorded_at + 1.hour,
      attributes: ordinary_evidence
    ).call.record

    error = assert_raises(AgencyCommand::Error) do
      ReinstateCapacity.new(
        agency: @agency,
        actor: @actor,
        projection_lock_version: graph[:projection].reload.lock_version,
        idempotency_key: "over-reinstate",
        recorded_at: @recorded_at + 2.hours,
        attributes: ordinary_evidence,
        releases: [
          { release_event: release, quantity: 3 },
          { release_event: release, quantity: 3 }
        ]
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_equal 0, graph[:pool].capacity_events.where(event_type: "reinstated").count
    assert_equal 3, graph[:projection].reload.current_supplier_capacity
  end

  test "idempotent replay does not catch up projection and tolerates omitted effective on across midnight" do
    graph = build_activated_established_capacity_graph(recorded_at: @recorded_at)
    future = IncreaseCapacity.new(
      agency: @agency,
      actor: @actor,
      pool: graph[:pool],
      quantity: 2,
      effective_on: Date.new(2026, 6, 10),
      projection_lock_version: graph[:projection].reload.lock_version,
      idempotency_key: "future-for-replay",
      recorded_at: @recorded_at + 1.hour,
      attributes: ordinary_evidence
    ).call.record

    first = nil
    projection_before = nil
    travel_to(@recorded_at + 2.hours) do
      first = IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: graph[:projection].reload.lock_version,
        idempotency_key: "omit-effective-on",
        attributes: ordinary_evidence
      ).call
      assert_equal :created, first.status
      projection_before = graph[:projection].reload.attributes.slice(
        "current_supplier_capacity",
        "last_event_id",
        "next_applies_at",
        "next_event_id",
        "lock_version"
      )
    end

    travel_to(future.applies_at + 1.minute) do
      replayed = IncreaseCapacity.new(
        agency: @agency,
        actor: @actor,
        pool: graph[:pool],
        quantity: 1,
        projection_lock_version: 0,
        idempotency_key: "omit-effective-on",
        attributes: ordinary_evidence
      ).call
      assert_equal :replayed, replayed.status
      assert_equal first.record.id, replayed.record.id
      assert_equal projection_before, graph[:projection].reload.attributes.slice(
        "current_supplier_capacity",
        "last_event_id",
        "next_applies_at",
        "next_event_id",
        "lock_version"
      )
    end
  end

  test "rebuild rejects draft pools without establishment" do
    graph = build_activated_unestablished_capacity_graph

    error = assert_raises(AgencyCommand::Error) do
      RebuildCapacityProjection.new(agency: @agency, pool: graph[:pool]).call
    end
    assert_equal :invalid_state, error.code
    assert_nil graph[:pool].reload.capacity_projection
  end

  test "app code does not branch on Rails env test" do
    text_extensions = %w[.rb .erb .js .css .html]
    app_files = Rails.root.glob("app/**/*").select do |path|
      path.file? && text_extensions.include?(path.extname)
    end
    offenders = app_files.select { |path| path.read.include?("Rails.env.test?") }

    assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s }
  end

  private

  def ordinary_evidence
    {
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-06-01",
      evidence_reference_note: "Supplier confirmed capacity change"
    }
  end
end
