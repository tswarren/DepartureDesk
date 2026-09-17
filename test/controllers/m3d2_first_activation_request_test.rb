require "test_helper"

class M3d2FirstActivationRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @supplier = create_capacity_supplier(@agency, "Request Activation Supplier")
    @departure = create_capacity_departure(@agency, name: "Request Activation")
    @departure.update!(
      status: "active", departure_reference: "D-846291",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Request Activation", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item], charging_supplier: @supplier,
      label: "Lodging", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source, stage: "contracted",
      status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @staff, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:request",
      readiness_provenance: "Signed"
    )
  end

  test "staff reviews one checklist and activates with confirmed-without-identifier evidence" do
    sign_in_as @staff
    get departure_arrangement_activation_path(@departure, @arrangement)
    assert_response :success
    assert_select "h1", text: "Activate arrangement"
    assert_select "input[name='cost_source_coverage_acknowledged']"
    assert_select "input[name='commitment_trigger_coverage_acknowledged']"
    assert_select "form[action='#{departure_arrangement_activation_path(@departure, @arrangement)}']", count: 1

    assert_difference -> { SupplierArrangementActivation.count }, 1 do
      post departure_arrangement_activation_path(@departure, @arrangement), params: {
        idempotency_key: SecureRandom.uuid,
        arrangement_lock_version: @arrangement.lock_version,
        version_lock_version: @version.lock_version,
        cost_source_coverage_acknowledged: "1",
        commitment_trigger_coverage_acknowledged: "1",
        confirmation: {
          evidence_kind: "supplier_confirmation",
          evidence_on: Date.current.iso8601,
          channel: "portal",
          reference_note: "Supplier confirmed exact version",
          confirmed_without_identifier_reason: "No identifier was issued"
        }
      }
    end
    assert_redirected_to departure_arrangement_path(@departure, @arrangement)
    assert_equal "active", @arrangement.reload.status
  end

  test "viewer sees the checklist without mutation controls and cross-Agency path is not found" do
    sign_in_as @viewer
    get departure_arrangement_activation_path(@departure, @arrangement)
    assert_response :success
    assert_select "input[type='submit']", count: 0

    other_departure = create_capacity_departure(
      agencies(:cove), name: "Other Agency Activation"
    )
    get departure_arrangement_activation_path(other_departure, @arrangement)
    assert_response :not_found
  end
end
