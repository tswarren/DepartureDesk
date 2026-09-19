# frozen_string_literal: true

require "test_helper"

class M3e3DepositRequirementsMilestonesTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Celebrity Supplier")
    @departure = create_capacity_departure(
      @agency, name: "Celebrity Departure", status: "draft"
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
      prefix: "Celebrity", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost
    create_confirmation_trigger
  end

  test "Celebrity path materializes initial and cumulative deposits attests and milestone replaces deadline" do
    initial = create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 5_000,
      currency: "USD",
      description: "Initial $50 deposit",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-01-15" },
      precision: "date_only"
    )
    final = create_deposit!(
      amount_shape: "cumulative_target",
      target_amount_minor_units: 50_000,
      currency: "USD",
      description: "Final cumulative $500 target",
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

    activation = activate_arrangement.record
    tranches = SupplierDepositRequirementTranche.where(supplier_arrangement_version: @version)
      .order(:materialized_at, :id)
    assert_equal 2, tranches.count

    initial_tranche = tranches.find_by!(supplier_deposit_requirement_definition: initial)
    final_tranche = tranches.find_by!(supplier_deposit_requirement_definition: final)
    assert_equal 5_000, initial_tranche.current_amount_minor_units
    assert_equal 45_000, final_tranche.current_amount_minor_units,
      "Cumulative $500 target leaves $450 after $50 initial"

    final_deadline = final_tranche.governing_deadline_occurrence
    assert_equal "deposit_due", final_deadline.deadline_type
    assert_equal Date.new(2027, 3, 11), final_deadline.calculated_on

    deposit_commitments = SupplierCommitment.where(opening_kind: "deposit_requirement")
    assert_equal 2, deposit_commitments.count
    assert deposit_commitments.all? { |row|
      row.supplier_confirmation_id.nil? && row.supplier_commitment_trigger_definition_id.nil?
    }

    initial_commitment = deposit_commitments.find_by!(
      supplier_deposit_requirement_tranche: initial_tranche
    )
    attestation = AttestSupplierDepositHandledExternally.new(
      agency: @agency, actor: @actor, commitment: initial_commitment,
      note: "Wire transfer confirmed with supplier finance",
      confirmed_complete: true,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert attestation.confirmed_complete?
    assert_equal "handled_externally", initial_commitment.reload.disposition_outcome
    assert_no_match(/paid/i, attestation.note)
    assert AuditEvent.exists?(action: "supplier_arrangement.deposit_attested_external")

    before_commitments = SupplierCommitment.where(opening_kind: "deposit_requirement").count
    milestone = RecordSupplierPlanningMilestone.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload,
      kind: "names_assigned_to_supplier",
      occurred_on: Date.new(2027, 2, 20),
      note: "Cabin names sent to supplier",
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_equal "names_assigned_to_supplier", milestone.kind
    assert_nil milestone.occurred_at
    assert_equal before_commitments,
      SupplierCommitment.where(opening_kind: "deposit_requirement").count

    final_tranche.reload
    replacement = final_tranche.governing_deadline_occurrence
    assert_not_equal final_deadline.id, replacement.id
    assert_equal Date.new(2027, 2, 20), replacement.calculated_on
    assert final_deadline.reload.superseded_at.present?
    assert AuditEvent.exists?(action: "supplier_arrangement.planning_milestone_recorded")
    assert AuditEvent.exists?(action: "supplier_arrangement.deposits_materialized")
    assert_equal activation.id, initial_tranche.supplier_arrangement_activation_id
  end

  test "deposit definitions freeze after activation" do
    definition = create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000,
      currency: "USD",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 30 },
      precision: "date_only"
    )
    activate_arrangement
    assert_raises(AgencyCommand::Error) do
      UpdateSupplierDepositRequirementDefinition.new(
        agency: @agency, actor: @actor, definition: definition.reload,
        attributes: deposit_attrs(
          amount_shape: "fixed_amount",
          fixed_amount_minor_units: 2_000,
          currency: "USD",
          rule_shape: "days_before_departure",
          rule_parameters: { "days" => 21 },
          precision: "date_only"
        ),
        lock_version: definition.lock_version
      ).call
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      definition.update_columns(description: "mutated", updated_at: Time.current)
    end
  end

  test "deposit_requirement opening shape rejects mixed FKs" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000,
      currency: "USD",
      rule_shape: "days_before_departure",
      rule_parameters: { "days" => 30 },
      precision: "date_only"
    )
    activate_arrangement
    tranche = SupplierDepositRequirementTranche.sole
    confirmation = @arrangement.supplier_confirmations.sole
    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCommitment.create!(
        agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
        supplier_arrangement_version: @version,
        opening_kind: "deposit_requirement",
        supplier_deposit_requirement_tranche: tranche,
        supplier_confirmation: confirmation,
        committed_supplier: @supplier,
        commitment_type: "monetary",
        description: "Mixed shape",
        amount_minor_units: 1_000,
        currency: "USD",
        calculation_snapshot: "bad",
        actor: @actor,
        opened_at: Time.current
      )
    end
  end

  test "projection refresh never opens deposit commitments from elapsed time" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 2_500,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => (Date.current - 5).iso8601 },
      precision: "date_only"
    )
    activate_arrangement(elapsed_deadlines_acknowledged: true)
    before = SupplierCommitment.where(opening_kind: "deposit_requirement").count
    occurrence = SupplierDeadlineOccurrence.find_by!(
      deadline_type: "deposit_due",
      supplier_arrangement_version: @version
    )
    RefreshSupplierDeadlineProjection.call(occurrence:, at: Time.current)
    RefreshDeadlineProjectionJob.perform_now(
      agency_id: @agency.id,
      supplier_deadline_occurrence_id: occurrence.id
    )
    assert_equal before, SupplierCommitment.where(opening_kind: "deposit_requirement").count
  end

  test "successor reconciliation blocks removing open deposit lineage" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 3_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-04-01" },
      precision: "date_only"
    )
    activate_arrangement
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency, actor: @actor, arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    copied = successor.supplier_deposit_requirement_definitions.sole
    assert copied.copied_from_id.present?

    RemoveSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, definition: copied,
      version_lock_version: successor.lock_version
    ).call

    error = assert_raises(AgencyCommand::Error) do
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
    end
    assert_match(/open Deposit/i, error.message)
  end

  test "attestation wording never uses paid" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_500,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only"
    )
    activate_arrangement
    commitment = SupplierCommitment.find_by!(opening_kind: "deposit_requirement")
    attestation = AttestSupplierDepositHandledExternally.new(
      agency: @agency, actor: @actor, commitment:,
      note: "Confirmed handled outside DepartureDesk via agency remittance",
      confirmed_complete: true,
      idempotency_key: SecureRandom.uuid
    ).call.record
    assert_no_match(/\bpaid\b/i, attestation.note)
    assert_equal "handled_externally", commitment.reload.disposition_outcome
  end

  private

  def deposit_attrs(**overrides)
    {
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000,
      currency: "USD",
      rule_shape: "fixed_date",
      rule_parameters: { "date" => "2027-05-01" },
      precision: "date_only",
      time_zone: "America/New_York",
      coverage_links: [],
      cost_links: []
    }.merge(overrides)
  end

  def create_deposit!(**attrs)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency, actor: @actor, version: @version.reload,
      attributes: deposit_attrs(**attrs),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def activate_arrangement(**overrides)
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

  def create_ready_cost
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Celebrity lodging cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted", status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included in package", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:celebrity",
      readiness_provenance: "Signed terms"
    )
  end

  def create_confirmation_trigger
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
end
