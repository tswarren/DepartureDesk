# frozen_string_literal: true

require "test_helper"

class M3e4QualifiedExposureTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Exposure Supplier")
    @departure = create_capacity_departure(
      @agency, name: "Exposure Departure", status: "draft"
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
      prefix: "Exposure", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @cost_source = create_calculated_cost!(amount_minor_units: 100_000, commission_minor_units: 10_000)
    create_confirmation_trigger!
  end

  test "activation rebuilds forecast and contingent bands without treating estimate as guaranteed" do
    activate_arrangement!

    summaries = SupplierExposureSummary.where(supplier_arrangement: @arrangement)
      .order(:qualification_band, :currency)
    bands = summaries.map(&:qualification_band)
    assert_includes bands, "forecast"
    assert_includes bands, "contingent"
    assert_not_includes bands, "guaranteed"

    forecast = summaries.find_by!(qualification_band: "forecast")
    assert_equal "known", forecast.completeness
    assert_equal 100_000, forecast.gross_minor_units
    assert_equal 10_000, forecast.expected_commission_minor_units
    assert_equal 90_000, forecast.expected_net_minor_units

    contingent = summaries.find_by!(qualification_band: "contingent")
    assert_equal 100_000, contingent.gross_minor_units
    assert_nil contingent.required_deposit_minor_units

    components = SupplierExposureComponent.where(supplier_arrangement: @arrangement)
    assert components.any?(&:forecast?)
    assert components.any?(&:contingent?)
    assert_equal 0, components.count(&:guaranteed?)
  end

  test "Celebrity deposits feed required deposit without mixing into gross cabin exposure" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 5_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-01-15" },
      precision: "date_only"
    )
    activate_arrangement!

    guaranteed = SupplierExposureSummary.find_by(
      supplier_arrangement: @arrangement, qualification_band: "guaranteed", currency: "USD"
    )
    assert_not_nil guaranteed
    assert_equal 5_000, guaranteed.required_deposit_minor_units
    assert_equal 0, guaranteed.gross_minor_units,
      "Deposit requirements must not inflate gross guaranteed cost"

    forecast = SupplierExposureSummary.find_by!(
      supplier_arrangement: @arrangement, qualification_band: "forecast", currency: "USD"
    )
    assert_equal 100_000, forecast.gross_minor_units
    assert_equal 10_000, forecast.expected_commission_minor_units
  end

  test "explicit qualify replaces contingent with guaranteed without double counting" do
    activate_arrangement!
    before = SupplierExposureComponent.where(
      supplier_arrangement: @arrangement, source_kind: "supplier_cost_source",
      source_id: @cost_source.id
    )
    assert before.any?(&:contingent?)
    assert_equal 0, before.count(&:guaranteed?)

    QualifySupplierContingentExposure.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      cost_source: @cost_source,
      note: "Minimum enrollment reached with supplier confirmation",
      idempotency_key: SecureRandom.uuid
    ).call

    after = SupplierExposureComponent.where(
      supplier_arrangement: @arrangement, source_kind: "supplier_cost_source",
      source_id: @cost_source.id
    )
    assert after.any?(&:guaranteed?)
    assert_equal 0, after.count(&:contingent?),
      "Contingent must be replaced, not retained alongside guaranteed"
    assert after.any?(&:forecast?)

    assert AuditEvent.exists?(action: "supplier_arrangement.exposure_qualified")
  end

  test "qualify idempotency replays and repair restores drifted projection" do
    activate_arrangement!
    key = SecureRandom.uuid
    first = QualifySupplierContingentExposure.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      cost_source: @cost_source, note: "Qualified once", idempotency_key: key
    ).call
    second = QualifySupplierContingentExposure.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      cost_source: @cost_source, note: "Qualified once", idempotency_key: key
    ).call
    assert_equal :created, first.status
    assert_equal :replayed, second.status
    assert_equal first.record.id, second.record.id

    component = SupplierExposureComponent.find_by!(
      supplier_arrangement: @arrangement, qualification_band: "guaranteed",
      source_kind: "supplier_cost_source", source_id: @cost_source.id
    )
    component.update_columns(gross_minor_units: 1, expected_net_minor_units: 1, updated_at: Time.current)

    RebuildSupplierExposureProjection.new(
      agency: @agency, actor: @actor, arrangement: @arrangement
    ).call
    assert_equal 100_000, component.reload.gross_minor_units
    assert_equal 90_000, component.expected_net_minor_units
  end

  test "repair job rebuilds without opening commitments or inventing domain events" do
    activate_arrangement!
    before_commitments = SupplierCommitment.count
    before_audits = AuditEvent.count

    RepairSupplierExposureProjectionJob.perform_now(
      agency_id: @agency.id,
      supplier_arrangement_id: @arrangement.id
    )

    assert_equal before_commitments, SupplierCommitment.count
    assert_equal before_audits, AuditEvent.count
    assert SupplierExposureSummary.exists?(supplier_arrangement: @arrangement)
  end

  test "estimate stage never enters guaranteed or contingent bands" do
    SupplierCostComponent.where(
      supplier_cost_definition_id: SupplierCostDefinition.where(supplier_cost_source: @cost_source).select(:id)
    ).delete_all
    SupplierCostDefinition.where(supplier_cost_source: @cost_source).delete_all
    definition = SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: @cost_source,
      stage: "estimate", status: "forecast_ready", mode: "calculated",
      currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:estimate",
      readiness_provenance: nil
    )
    SupplierCostComponent.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Estimate fare", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: 50_000,
      pass_through: false, position: 1
    )
    definition.update!(
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition.reload)
    )
    activate_arrangement!

    bands = SupplierExposureComponent.where(
      supplier_arrangement: @arrangement, source_kind: "supplier_cost_source"
    ).pluck(:qualification_band).uniq
    assert_equal [ "forecast" ], bands
  end

  private

  def create_calculated_cost!(amount_minor_units:, commission_minor_units:)
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Cabin cost", position: 1
    )
    definition = SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "calculated",
      currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:exposure-cabin",
      readiness_provenance: "Signed terms"
    )
    charge = SupplierCostComponent.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Cabin fare", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units:,
      pass_through: false, position: 1
    )
    SupplierCostComponent.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Expected commission", economic_role: "expected_commission",
      calculation_kind: "fixed", amount_minor_units: commission_minor_units,
      pass_through: false, position: 2
    )
    definition.update!(
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition.reload)
    )
    charge
    source
  end

  def create_confirmation_trigger!
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Confirm cabins",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def create_deposit!(**attrs)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
      attributes: deposit_attrs(**attrs),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def deposit_attrs(**overrides)
    {
      description: "Deposit",
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-02-01" },
      precision: "date_only",
      time_zone: "America/New_York",
      coverage_links: [],
      cost_links: []
    }.merge(overrides)
  end

  def activate_arrangement!(**overrides)
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: false,
      **overrides
    ).call
  end
end
