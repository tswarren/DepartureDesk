require "test_helper"

class M3D4EffectiveCapacityRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @departure = create_capacity_departure(@agency, name: "M3D4 Effective Capacity")
    @contractor = create_capacity_supplier(@agency, "M3D4 Contractor")
    @provider = create_capacity_supplier(@agency, "M3D4 Provider")
    @recorded_at = Time.zone.parse("2026-06-02 12:00:00 UTC")
    @graph = build_activated_established_capacity_graph(
      actor: @admin,
      recorded_at: @recorded_at
    )
  end

  test "viewer sees Current Supplier capacity and history without mutation forms" do
    sign_in_as @viewer

    get departure_arrangement_path(@departure, @graph[:arrangement])
    assert_response :success
    assert_select "#current-supplier-capacity", text: /Current Supplier capacity/
    assert_select "a[href='#{capacity_pool_path}']", text: @graph[:pool_definition].label

    get capacity_pool_path
    assert_response :success
    assert_select "p.dd-eyebrow", text: "Current Supplier capacity"
    assert_select "dt", text: "Current Supplier capacity"
    assert_select "form[action='#{capacity_events_path}']", count: 0
    assert_select "form[action='#{capacity_reconciliations_path}']", count: 0
    assert_select "form[action='#{capacity_rebuild_path}']", count: 0
  end

  test "staff records evidence-backed events and reconciliations" do
    sign_in_as @staff

    assert_difference -> { @graph[:pool].capacity_events.count }, 1 do
      post capacity_events_path, params: {
        projection_lock_version: @graph[:projection].reload.lock_version,
        idempotency_key: SecureRandom.uuid,
        capacity_event: {
          event_type: "increased",
          quantity: 2,
          effective_on: "2026-06-02",
          evidence_kind: "supplier_confirmation",
          evidence_on: "2026-06-02",
          evidence_reference_note: "Supplier approved two more cabins."
        }
      }
    end
    assert_redirected_to capacity_pool_path
    assert_equal 10, @graph[:projection].reload.current_supplier_capacity

    assert_difference -> { @graph[:pool].capacity_reconciliations.count }, 1 do
      post capacity_reconciliations_path, params: {
        projection_lock_version: @graph[:projection].reload.lock_version,
        idempotency_key: SecureRandom.uuid,
        capacity_reconciliation: {
          observed_quantity: 10,
          observed_at: (Time.current + 1.hour).iso8601,
          evidence_kind: "supplier_message",
          evidence_on: "2026-06-02",
          evidence_reference_note: "Supplier count matched the ledger."
        }
      }
    end
    assert_redirected_to capacity_pool_path
    assert_predicate @graph[:pool].capacity_reconciliations.order(:recorded_at).last, :matched?
  end

  test "staff reaches release reinstatement withdrawal and correction commands" do
    sign_in_as @staff

    release = post_event("released", quantity: 2)
    post_event("reinstated", quantity: 1, release_event_id: release.id)
    post_event("withdrawn", quantity: 1)
    post_event("corrected_down", quantity: 1, corrects_event_id: @graph[:established_event].id)
    post_event("corrected_up", quantity: 1, corrects_event_id: @graph[:established_event].id)

    assert_equal(
      %w[corrected_down corrected_up established reinstated released withdrawn],
      @graph[:pool].capacity_events.order(:event_type).pluck(:event_type)
    )
    assert_equal 6, @graph[:projection].reload.current_supplier_capacity
  end

  test "staff resolves an open reconciliation through a linked correction" do
    sign_in_as @staff
    post capacity_reconciliations_path, params: {
      projection_lock_version: @graph[:projection].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      capacity_reconciliation: {
        observed_quantity: 10,
        observed_at: (Time.current + 1.hour).iso8601,
        evidence_kind: "supplier_message",
        evidence_on: "2026-06-02",
        evidence_reference_note: "Supplier reported ten cabins."
      }
    }
    reconciliation = @graph[:pool].capacity_reconciliations.order(:recorded_at, :id).last
    assert_predicate reconciliation, :open_discrepancy?

    post capacity_events_path, params: {
      projection_lock_version: @graph[:projection].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      capacity_event: evidence_event_params(event_type: "corrected_up", quantity: 2).merge(
        capacity_reconciliation_id: reconciliation.id,
        resolution_note: "Aligned the ledger to the Supplier observation."
      )
    }

    assert_redirected_to capacity_pool_path
    assert_predicate reconciliation.reload, :resolved?
    assert_equal 10, @graph[:projection].reload.current_supplier_capacity
  end

  test "staff override is rejected and Administrator override is marked" do
    sign_in_as @staff
    assert_no_difference -> { @graph[:pool].capacity_events.count } do
      post capacity_events_path, params: override_event_params
    end
    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /not allowed/

    sign_out
    sign_in_as @admin
    assert_difference -> { @graph[:pool].capacity_events.count }, 1 do
      post capacity_events_path, params: override_event_params.merge(
        idempotency_key: SecureRandom.uuid,
        projection_lock_version: @graph[:projection].reload.lock_version
      )
    end
    event = @graph[:pool].capacity_events.order(:recorded_at, :id).last
    assert_predicate event, :override?
    assert_equal "Administrator verified the exception.", event.override_reason
  end

  test "inactive Supplier recovery allows reductions but not new increases" do
    @provider.update!(status: "inactive")
    sign_in_as @staff

    assert_difference -> { @graph[:pool].capacity_events.where(event_type: "released").count }, 1 do
      post capacity_events_path, params: {
        projection_lock_version: @graph[:projection].reload.lock_version,
        idempotency_key: SecureRandom.uuid,
        capacity_event: evidence_event_params(event_type: "released", quantity: 1)
      }
    end
    assert_redirected_to capacity_pool_path

    assert_no_difference -> { @graph[:pool].capacity_events.count } do
      post capacity_events_path, params: {
        projection_lock_version: @graph[:projection].reload.lock_version,
        idempotency_key: SecureRandom.uuid,
        capacity_event: evidence_event_params(event_type: "increased", quantity: 1)
      }
    end
    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /supplying supplier is not active/i
    assert_select "select[name='capacity_event[event_type]'] option[value='increased']", count: 0
    assert_select "select[name='capacity_event[event_type]'] option[value='reinstated']", count: 0
  end

  test "departed lifecycle retains history without presenting mutation controls" do
    @departure.update!(status: "departed", departed_at: Time.current)
    sign_in_as @staff

    get capacity_pool_path

    assert_response :success
    assert_select "table", text: /Established/
    assert_select "form[action='#{capacity_events_path}']", count: 0
    assert_select "form[action='#{capacity_reconciliations_path}']", count: 0
    assert_select "form[action='#{capacity_rebuild_path}']", count: 0
    assert_match "not available in this Departure lifecycle state", response.body
  end

  test "staff rebuilds a drifted projection from the immutable ledger" do
    @graph[:projection].update_columns(current_supplier_capacity: 1)
    sign_in_as @staff

    assert_no_difference -> { @graph[:pool].capacity_events.count } do
      post capacity_rebuild_path
    end

    assert_redirected_to capacity_pool_path
    assert_equal 8, @graph[:projection].reload.current_supplier_capacity
  end

  test "another Agency capacity Pool is not found" do
    other_agency = agencies(:cove)
    other_departure = create_capacity_departure(other_agency, name: "Cove Effective Capacity")
    other_contractor = create_capacity_supplier(other_agency, "Cove M3D4 Contractor")
    other_provider = create_capacity_supplier(other_agency, "Cove M3D4 Provider")
    other_graph = build_activated_established_capacity_graph(
      agency: other_agency,
      departure: other_departure,
      contractor: other_contractor,
      provider: other_provider,
      actor: agency_users(:cove_admin),
      prefix: "Cove M3D4",
      recorded_at: @recorded_at
    )
    sign_in_as @admin

    get departure_arrangement_capacity_pool_path(
      other_departure, other_graph[:arrangement], other_graph[:pool]
    )
    assert_response :not_found
  end

  private

  def capacity_pool_path
    departure_arrangement_capacity_pool_path(
      @departure, @graph[:arrangement], @graph[:pool]
    )
  end

  def capacity_events_path
    departure_arrangement_capacity_pool_events_path(
      @departure, @graph[:arrangement], @graph[:pool]
    )
  end

  def capacity_reconciliations_path
    departure_arrangement_capacity_pool_reconciliations_path(
      @departure, @graph[:arrangement], @graph[:pool]
    )
  end

  def capacity_rebuild_path
    departure_arrangement_capacity_pool_rebuild_path(
      @departure, @graph[:arrangement], @graph[:pool]
    )
  end

  def evidence_event_params(event_type:, quantity:)
    {
      event_type: event_type,
      quantity: quantity,
      evidence_kind: "supplier_confirmation",
      evidence_on: "2026-06-02",
      evidence_reference_note: "Supplier approved the capacity change."
    }
  end

  def override_event_params
    {
      projection_lock_version: @graph[:projection].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      capacity_event: {
        event_type: "increased",
        quantity: 1,
        override: "1",
        override_reason: "Administrator verified the exception."
      }
    }
  end

  def post_event(event_type, quantity:, **lineage)
    post capacity_events_path, params: {
      projection_lock_version: @graph[:projection].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      capacity_event: evidence_event_params(
        event_type: event_type,
        quantity: quantity
      ).merge(lineage)
    }
    assert_redirected_to capacity_pool_path
    @graph[:pool].capacity_events.order(:recorded_at, :id).last
  end
end
