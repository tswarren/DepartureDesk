# frozen_string_literal: true

require "test_helper"

class M3e5NeedsAttentionCatalogTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ApplicationHelper

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

  test "due soon findings persist before attention_at and overdue labels use overdue_at on read" do
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
      at: Time.zone.parse("2027-01-10 12:00:00")
    ).call
    finding = SupplierAttentionFinding.find_by!(
      supplier_arrangement: @arrangement,
      detector_key: "actionable_commitment_due_soon",
      source_id: commitment.id
    )
    assert_not finding.visible?(Time.zone.parse("2027-01-10 12:00:00")),
      "Finding must exist before the warning boundary but stay hidden until attention_at"
    assert finding.visible?(Time.zone.parse("2027-01-18 12:00:00"))
    assert_not finding.overdue?(Time.zone.parse("2027-01-18 12:00:00"))
    assert finding.overdue?(Time.zone.parse("2027-01-21 12:00:00")),
      "Overdue labeling must use stored overdue_at without a status-changing rebuild"
    assert_equal "Overdue", attention_severity_label(
      finding, at: Time.zone.parse("2027-01-21 12:00:00")
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
    finding = SupplierAttentionFinding.find_by!(
      supplier_arrangement: @arrangement,
      detector_key: "actionable_commitment_due_soon"
    )
    assert finding.overdue?(Time.zone.parse("2027-01-21 12:00:00"))
  end

  test "handled Celebrity deposit through successor activation does not invent incomplete finding" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 5_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-01-15" },
      precision: "date_only"
    )
    activate_arrangement!
    commitment = SupplierCommitment.find_by!(opening_kind: "deposit_requirement")
    AttestSupplierDepositHandledExternally.new(
      agency: @agency, actor: @actor, commitment:,
      note: "Confirmed handled outside DepartureDesk via remittance",
      confirmed_complete: true,
      idempotency_key: SecureRandom.uuid
    ).call
    assert_equal "handled_externally", commitment.reload.disposition_outcome

    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    ActivateSupplierArrangementVersion.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      version: successor.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: successor.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation", evidence_on: Date.current,
        channel: "portal", reference_note: "Successor evidence",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call

    copied = successor.supplier_deposit_requirement_definitions.sole
    assert_nil SupplierDepositRequirementTranche.find_by(
      supplier_deposit_requirement_definition_id: copied.id
    ), "Unchanged terminal deposit must not rematerialize on successor activation"
    assert_not SupplierAttentionFinding.exists?(
      supplier_arrangement: @arrangement,
      detector_key: "deposit_calculation_incomplete",
      source_id: copied.id
    )
  end

  test "deadline catch-up and planning milestone share lock order without deadlock" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 2_500,
      currency: "USD",
      rule_shape: "earlier_of",
      rule_parameters: {
        "arms" => [
          { "rule_shape" => "fixed_date", "rule_parameters" => { "date" => "2027-03-11" } },
          {
            "rule_shape" => "planning_milestone",
            "rule_parameters" => { "kind" => "names_assigned_to_supplier" }
          }
        ]
      },
      precision: "date_only"
    )
    activate_arrangement!
    occurrence = SupplierDeadlineOccurrence.find_by!(
      supplier_arrangement_version: @version.reload,
      deadline_type: "deposit_due"
    )

    outcomes = race do |index|
      if index.zero?
        RefreshDeadlineProjectionJob.perform_now(
          agency_id: @agency.id,
          supplier_deadline_occurrence_id: occurrence.id
        )
        :catch_up
      else
        RecordSupplierPlanningMilestone.new(
          agency: @agency,
          actor: @actor,
          arrangement: @arrangement.reload,
          version: @version.reload,
          kind: "names_assigned_to_supplier",
          occurred_on: Date.new(2027, 2, 1),
          idempotency_key: SecureRandom.uuid
        ).call
      end
    end

    assert outcomes.none? { |outcome| outcome.is_a?(ActiveRecord::Deadlocked) },
      "Catch-up must not reverse Arrangement/occurrence lock order against milestone replacement"
    assert outcomes.any? { |outcome| outcome == :catch_up }
    assert outcomes.any? { |outcome| outcome.is_a?(AgencyCommand::Result) }
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

  def create_deposit!(**attrs)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
      attributes: {
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: 1_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-05-01" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [],
        cost_links: []
      }.merge(attrs),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def race
    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          yield index
        end
      rescue StandardError => error
        error
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    outcomes = threads.map(&:value)
    outcomes.each do |outcome|
      next if outcome == :catch_up
      next if outcome.is_a?(AgencyCommand::Result)
      next if outcome.is_a?(AgencyCommand::Error) &&
        %i[invalid invalid_state conflict].include?(outcome.code)
      next if outcome.is_a?(ActiveRecord::Deadlocked)

      raise outcome if outcome.is_a?(Exception)
    end
    outcomes
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
