# frozen_string_literal: true

require "test_helper"

class M3e5NeedsAttentionCatalogTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @supplier = create_capacity_supplier(@agency, "Attention Supplier")
    @departure = create_capacity_departure(
      @agency, name: "Attention Departure", status: "draft"
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
      prefix: "Attention", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost!
    create_confirmation_trigger!
  end

  test "activation rebuilds open commitment without future deadline finding" do
    activate_arrangement!

    findings = SupplierAttentionFinding.where(supplier_arrangement: @arrangement)
    assert findings.any?(&:open_commitment_without_future_deadline?)
    finding = findings.find(&:open_commitment_without_future_deadline?)
    assert_equal "dispose_or_satisfy_commitment", finding.action_group
    assert_equal "commitments", finding.primary_path
    assert finding.visible?
  end

  test "deadline warning lead uses definition override over agency default" do
    @agency.update!(attention_warning_lead_days: 14)
    create_actionable_deadline!(
      rule_parameters: { "date" => "2027-01-20" },
      warning_lead_days: 2
    )
    activate_arrangement!

    occurrence = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: @version.reload
    )
    projection = RefreshSupplierDeadlineProjection.call(
      occurrence:,
      at: Time.zone.parse("2027-01-10 12:00:00")
    )
    assert_equal Time.find_zone!("America/New_York").local(2027, 1, 18),
      projection.warning_starts_at
  end

  test "agency default warning lead applies when definition lead is blank" do
    @agency.update!(attention_warning_lead_days: 5)
    create_actionable_deadline!(
      rule_parameters: { "date" => "2027-01-20" },
      warning_lead_days: nil
    )
    activate_arrangement!

    occurrence = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: @version.reload
    )
    projection = RefreshSupplierDeadlineProjection.call(
      occurrence:,
      at: Time.zone.parse("2027-01-10 12:00:00")
    )
    assert_equal Time.find_zone!("America/New_York").local(2027, 1, 15),
      projection.warning_starts_at
  end

  test "due soon and overdue commitment detectors evaluate stored boundaries at read time" do
    create_actionable_deadline!(
      rule_parameters: { "date" => "2027-01-20" },
      warning_lead_days: 3
    )
    activate_arrangement!
    commitment = SupplierCommitment.where(
      supplier_arrangement: @arrangement, opening_kind: "deadline_requirement"
    ).order(:id).last
    assert commitment.open_state?

    RebuildSupplierAttentionProjectionAlreadyLocked.new(
      agency: @agency, arrangement: @arrangement.reload,
      at: Time.zone.parse("2027-01-18 12:00:00")
    ).call
    due_soon = SupplierAttentionFinding.find_by!(
      supplier_arrangement: @arrangement,
      detector_key: "actionable_commitment_due_soon",
      source_id: commitment.id
    )
    assert due_soon.visible?(Time.zone.parse("2027-01-18 12:00:00"))
    assert_not due_soon.overdue?(Time.zone.parse("2027-01-18 12:00:00"))

    RebuildSupplierAttentionProjectionAlreadyLocked.new(
      agency: @agency, arrangement: @arrangement.reload,
      at: Time.zone.parse("2027-01-21 12:00:00")
    ).call
    assert SupplierAttentionFinding.exists?(
      supplier_arrangement: @arrangement,
      detector_key: "actionable_commitment_overdue",
      source_id: commitment.id
    )
    assert_not SupplierAttentionFinding.exists?(
      supplier_arrangement: @arrangement,
      detector_key: "actionable_commitment_due_soon",
      source_id: commitment.id
    )
  end

  test "waiver clears needs-attention finding while accepted exception remains" do
    activate_arrangement!
    commitment = SupplierCommitment.where(
      supplier_arrangement: @arrangement, opening_kind: "confirmation_trigger"
    ).order(:id).last
    assert SupplierAttentionFinding.exists?(
      source_kind: "supplier_commitment", source_id: commitment.id
    )

    WaiveSupplierCommitment.new(
      agency: @agency,
      actor: agency_users(:harbor_admin),
      commitment:,
      reason: "Accepted supplier exception for this Departure",
      accepted_risk_acknowledged: true,
      idempotency_key: SecureRandom.uuid
    ).call

    assert_not SupplierAttentionFinding.exists?(
      source_kind: "supplier_commitment", source_id: commitment.id
    )
    assert_equal "waived", commitment.reload.disposition_outcome
  end

  test "incomplete exposure components produce inspect_exposure findings" do
    activate_arrangement!
    component = SupplierExposureComponent.where(supplier_arrangement: @arrangement).first
    component.update_columns(
      completeness: "incomplete",
      gross_minor_units: nil,
      expected_commission_minor_units: nil,
      expected_net_minor_units: nil,
      updated_at: Time.current
    )

    RebuildSupplierAttentionProjectionAlreadyLocked.new(
      agency: @agency, arrangement: @arrangement.reload
    ).call

    finding = SupplierAttentionFinding.find_by!(
      detector_key: "exposure_incomplete",
      source_kind: "supplier_exposure_component",
      source_id: component.id
    )
    assert_equal "inspect_exposure", finding.action_group
    assert_equal "exposure", finding.primary_path
  end

  test "deadline projection catch-up rebuilds attention without inventing domain events" do
    create_actionable_deadline!(
      rule_parameters: { "date" => "2027-01-20" },
      warning_lead_days: 2
    )
    activate_arrangement!
    occurrence = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: @version.reload
    )
    before_commitments = SupplierCommitment.count
    before_audits = AuditEvent.count

    travel_to Time.zone.parse("2027-01-21 12:00:00") do
      RefreshDeadlineProjectionJob.perform_now(
        agency_id: @agency.id,
        supplier_deadline_occurrence_id: occurrence.id
      )
    end

    assert_equal before_commitments, SupplierCommitment.count
    assert_equal before_audits, AuditEvent.count
    assert SupplierAttentionFinding.exists?(
      supplier_arrangement: @arrangement,
      detector_key: "actionable_commitment_overdue"
    )
  end

  test "agency timing update refreshes deadline projections using most-specific-wins" do
    create_actionable_deadline!(
      rule_parameters: { "date" => "2027-01-20" },
      warning_lead_days: nil
    )
    activate_arrangement!
    occurrence = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: @version.reload
    )

    UpdateAgencyProfile.new(
      agency: @agency,
      actor: @admin,
      name: @agency.name,
      legal_name: @agency.legal_name,
      country_code: @agency.country_code,
      default_currency: @agency.default_currency,
      default_timezone: @agency.default_timezone,
      attention_warning_lead_days: 4,
      lock_version: @agency.lock_version
    ).call

    projection = SupplierDeadlineProjection.find_by!(
      supplier_deadline_occurrence_id: occurrence.id
    )
    assert_equal 4, @agency.reload.attention_warning_lead_days
    assert_equal Time.find_zone!("America/New_York").local(2027, 1, 16),
      projection.warning_starts_at
  end

  private

  def create_ready_cost!
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
      readiness_fingerprint: "sha256:attention-cabin",
      readiness_provenance: "Signed terms"
    )
    SupplierCostComponent.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Cabin fare", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: 100_000,
      pass_through: false, position: 1
    )
    definition.update!(
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition.reload)
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
      description: "Confirm cabins",
      fixed_quantity: 1,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def create_actionable_deadline!(**overrides)
    CreateSupplierDeadlineDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
      attributes: {
        deadline_type: "cancellation_cutoff",
        kind: "actionable",
        description: "Cancellation cutoff",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-01-20" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        warning_lead_days: 2,
        coverage_links: [],
        commitment_lines: [ {
          authority_shape: "fixed_quantity",
          description: "Release held inventory",
          committed_supplier_id: @supplier.id,
          fixed_quantity: 1,
          quantity_basis: "resource_units"
        } ]
      }.merge(overrides),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
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
        channel: "portal", reference_note: "Attention activation",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
  end
end
