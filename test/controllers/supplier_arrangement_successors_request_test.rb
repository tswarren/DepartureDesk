require "test_helper"

class SupplierArrangementSuccessorsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @supplier = create_capacity_supplier(@agency, "Successor Request Supplier")
    @departure = create_capacity_departure(@agency, name: "Successor Request")
    @departure.update!(
      status: "active", departure_reference: "D-846292", first_activated_at: Time.current
    )
    graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Request successor",
      capacity_management: "unmanaged"
    )
    @arrangement = graph[:arrangement]
    @version = graph[:version]
    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: graph[:item],
      charging_supplier: @supplier,
      label: "Entered cost",
      position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Included",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:request-successor",
      readiness_provenance: "Signed"
    )
    activate_first
  end

  test "staff creates a successor and sees exact workspace actions" do
    sign_in_as @staff
    get departure_arrangement_path(@departure, @arrangement)
    assert_response :success
    assert_select "form[action='#{successor_departure_arrangement_path(@departure, @arrangement)}']"
    assert_select "button", text: "Create successor"

    assert_difference -> { SupplierArrangementVersion.count }, 1 do
      post successor_departure_arrangement_path(@departure, @arrangement), params: {
        arrangement_lock_version: @arrangement.reload.lock_version,
        version_lock_version: @version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      }
    end
    assert_redirected_to departure_arrangement_path(@departure, @arrangement)

    follow_redirect!
    assert_select "p", text: /Successor draft workspace/
    assert_select "a", text: "Activate successor"
    assert_select "a", text: "Abandon successor"
  end

  test "viewer cannot create a successor and sees no successor mutation control" do
    sign_in_as @viewer
    get departure_arrangement_path(@departure, @arrangement)
    assert_response :success
    assert_select "button", text: "Create successor", count: 0

    post successor_departure_arrangement_path(@departure, @arrangement), params: {
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    }
    assert_redirected_to root_path
    assert_equal 1, @arrangement.versions.count
  end

  private

  def activate_first
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      version: @version,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "First exact version confirmed",
        confirmed_without_identifier_reason: "No identifier issued"
      },
      cost_source_coverage_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call
  end
end
