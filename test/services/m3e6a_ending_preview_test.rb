# frozen_string_literal: true

require "test_helper"

class M3e6aEndingPreviewTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @supplier = create_capacity_supplier(@agency, "Ending Preview Supplier")
    @departure = create_capacity_departure(
      @agency, name: "Ending Preview Departure", status: "draft"
    )
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 6, 15),
      ends_on: Date.new(2027, 6, 22),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Ending", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost!
    create_confirmation_trigger!
    activate_arrangement!
  end

  test "preview binds digest over arrangement version blockers eligible and selected cascades" do
    result = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement
    ).call
    preview = result.record

    assert_equal :created, result.status
    assert_equal 64, preview.digest_sha256.length
    assert preview.matches_token?(result.raw_token)
    assert_operator preview.expires_at, :>, Time.current
    assert_includes preview.payload.fetch("reason_choices"), "planning_concluded"
    assert preview.payload.fetch("cascades").any? { |row|
      row["kind"] == "cancel_open_commitment"
    }
    assert preview.payload.fetch("blockers").any? { |row| row["code"] == "open_commitments" }
  end

  test "open commitment blocker lists only currently open commitments" do
    open_ids = SupplierCommitment.where(supplier_arrangement: @arrangement)
      .select(&:open_state?).map(&:id).sort
    result = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement
    ).call
    blocker = result.record.payload.fetch("blockers").find { |row| row["code"] == "open_commitments" }
    assert blocker, "expected open_commitments blocker while open commitments remain"
    assert_equal open_ids, blocker.fetch("target_ids").sort
  end

  test "digest expires and find_valid_preview rejects expired tokens" do
    result = PreviewEndSupplierArrangement.new(
      agency: @agency, actor: @actor, arrangement: @arrangement
    ).call
    result.record.update_columns(expires_at: 1.minute.ago, updated_at: Time.current)

    error = assert_raises(AgencyCommand::Error) do
      PreviewEndSupplierArrangement.find_valid_preview!(
        agency: @agency, arrangement: @arrangement, raw_token: result.raw_token
      )
    end
    assert_equal :conflict, error.code
  end

  test "viewer cannot preview ending" do
    error = assert_raises(AgencyCommand::Error) do
      PreviewEndSupplierArrangement.new(
        agency: @agency, actor: @viewer, arrangement: @arrangement
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "cross-agency arrangement is not found" do
    other = agencies(:cove)
    error = assert_raises(ActiveRecord::RecordNotFound) do
      PreviewEndSupplierArrangement.new(
        agency: other, actor: agency_users(:cove_admin), arrangement: @arrangement
      ).call
    end
    assert error
  end

  private

  def create_ready_cost!
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Ending cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:ending",
      readiness_provenance: "Signed"
    )
  end

  def create_confirmation_trigger!
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def activate_arrangement!
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
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
  end
end
