# frozen_string_literal: true

require "test_helper"

class M3e7aEndingAndExposureUiRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
  end

  test "viewer cannot open ending preview" do
    sign_in_as @viewer
    arrangement = active_arrangement!
    get end_departure_arrangement_path(arrangement.departure, arrangement)
    assert_redirected_to root_url
  end

  test "ending validation error preserves recoverable alert" do
    sign_in_as @staff
    arrangement = active_arrangement!
    get end_departure_arrangement_path(arrangement.departure, arrangement)
    assert_response :success
    assert_select "#ending-cascades-heading"

    post end_departure_arrangement_path(arrangement.departure, arrangement), params: {
      preview_token: "not-a-real-token",
      idempotency_key: "keep-me-#{SecureRandom.uuid}",
      ending_reason: "planning_concluded"
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
  end

  private

  def active_arrangement!
    supplier = create_capacity_supplier(@agency, "UI Recovery Supplier")
    departure = create_capacity_departure(@agency, name: "UI Recovery Departure", status: "draft")
    departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 6, 15),
      ends_on: Date.new(2027, 6, 22),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    graph = create_capacity_graph(
      agency: @agency, departure:,
      contractor: supplier, provider: supplier,
      prefix: "UI", capacity_management: "unmanaged"
    )
    arrangement = graph[:arrangement]
    version = graph[:version]
    source = SupplierCostSource.create!(
      agency: @agency, departure:,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      arrangement_item: graph[:item],
      charging_supplier: supplier,
      label: "UI cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure:,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @staff, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:ui7a",
      readiness_provenance: "Signed"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure:,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      committed_supplier: supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @staff, arrangement:,
      version: version.reload,
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Approved",
        confirmed_without_identifier_reason: "Later"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false
    ).call
    arrangement.reload
  end
end
