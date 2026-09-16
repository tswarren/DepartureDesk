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
