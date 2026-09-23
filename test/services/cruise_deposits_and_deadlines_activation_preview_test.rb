# frozen_string_literal: true

require "test_helper"

class CruiseDepositsAndDeadlinesActivationPreviewTest < ActiveSupport::TestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin
    @arrangement = @setup[:arrangement]
    @version = @arrangement.versions.sole
    @pool = @version.capacity_pool_definitions.sole.capacity_pool
    @item = @arrangement.arrangement_items.sole
  end

  test "activation preview is write-free and lists definition-level consequences" do
    create_typed_deadline!
    create_typed_deposit!

    before_occurrences = SupplierDeadlineOccurrence.count
    before_tranches = SupplierDepositRequirementTranche.count
    before_commitments = SupplierCommitment.count
    before_audits = AuditEvent.count
    before_keys = AgencyCommandIdempotencyKey.count
    lock = @version.lock_version

    result = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version,
      version_lock_version: lock
    )

    assert_equal "ready", result.status
    assert_equal false, result.stale?
    assert_equal 2, result.rows.size
    deposit_row = result.rows.find { |row| row.kind == "deposit" }
    deadline_row = result.rows.find { |row| row.kind == "deadline" }
    assert deposit_row.display_name.present?
    assert deposit_row.amount_sentence.present?
    assert deposit_row.due_sentence.present?
    assert deposit_row.will_open_commitment?
    assert_equal "#cruise-deposit-#{deposit_row.definition_id}", deposit_row.editor_anchor
    assert deadline_row.will_open_commitment?
    assert_includes result.activation_path, "/activation"

    assert_equal before_occurrences, SupplierDeadlineOccurrence.count
    assert_equal before_tranches, SupplierDepositRequirementTranche.count
    assert_equal before_commitments, SupplierCommitment.count
    assert_equal before_audits, AuditEvent.count
    assert_equal before_keys, AgencyCommandIdempotencyKey.count
    assert_equal lock, @version.reload.lock_version
  end

  test "activation preview reports stale lock without writing" do
    result = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version,
      version_lock_version: @version.lock_version - 1
    )

    assert_equal "stale", result.status
    assert result.stale?
    assert_equal [], result.rows
  end

  test "activation preview rows match post-activation materializations for Celebrity fixture" do
    create_typed_deposit!
    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: @arrangement,
      version: @version,
      version_lock_version: @version.lock_version
    )
    deposit_preview = preview.rows.find { |row| row.kind == "deposit" }

    prepare_and_activate!

    tranche = SupplierDepositRequirementTranche.find_by!(
      supplier_arrangement_version: @version
    )
    occurrence = tranche.governing_deadline_occurrence
    assert_equal deposit_preview.amount_sentence,
      Money.new(tranche.current_amount_minor_units, tranche.currency).format
    assert_includes deposit_preview.due_sentence, occurrence.calculated_on.iso8601
    assert SupplierCommitment.exists?(
      opening_kind: "deposit_requirement",
      supplier_deposit_requirement_tranche: tranche
    )
    assert_empty(
      SupplierCommitmentDisposition.where(outcome: "paid")
    )
  end

  private

  def create_typed_deadline!
    CreateSupplierDeadlineDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        deadline_type: "option_or_release_date",
        kind: "actionable",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-02-01" },
        precision: "date_only",
        time_zone: "America/New_York",
        cardinality: "one_shared",
        coverage_links: [ { arrangement_item_id: @item.id } ],
        commitment_lines: [
          {
            authority_shape: "fixed_quantity",
            description: "Retain or release eight cabins",
            committed_supplier_id: @contractor.id,
            fixed_quantity: 8,
            quantity_basis: "resource_units"
          }
        ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
  end

  def create_typed_deposit!
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 5_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-09-20" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pool_coverage(@pool)
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
  end

  def pool_coverage(pool)
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    [ {
      capacity_pool_id: pool.id,
      arrangement_item_id: definition.arrangement_item_id,
      service_occurrence_id: definition.service_occurrence_id,
      supplier_resource_id: definition.supplier_resource_id
    } ]
  end

  def prepare_and_activate!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )

    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @item,
      charging_supplier: @contractor,
      label: "Cruise fare",
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
      zero_cost_reason: "Included in package",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:2bc-preview",
      readiness_provenance: "Signed terms"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Eight guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )

    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      version: @version,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
  end

  def create_cruise_with_cabin
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    { arrangement: arrangement, resource: cabin.record.resource }
  end
end
