# frozen_string_literal: true

require "test_helper"

class M4d1CruiseNumericCapacityEvaluationTest < ActiveSupport::TestCase
  include CapacityGraphHelper
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
  end

  test "a numeric pool with no opening quantity stays incomplete" do
    setup = create_sailing!
    version = setup[:version]
    pool = add_cabin!(setup, name: "Prime Oceanview", code: "O1", inventory_mode: "block", quantity: 8)
    definition = version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    definition.update_columns(proposed_opening_quantity: nil)
    deposit = create_deposit!(setup, pools: [ pool ], rate_minor_units: 5_000)

    error = assert_raises(SupplierDepositAmountEvaluator::IncompleteCalculation) do
      SupplierDepositAmountEvaluator.call(
        definition: deposit,
        version: version.reload,
        arrangement: setup[:arrangement],
        mode: :preview
      )
    end

    assert_match(/Proposed opening quantity is incomplete/i, error.message)
    assert_nil definition.reload.proposed_opening_quantity
  end

  test "a blocked cabin plus an on request cabin evaluates and materializes the blocked quantity only" do
    setup = create_sailing!
    blocked = add_cabin!(setup, name: "Prime Oceanview", code: "O1", inventory_mode: "block", quantity: 8)
    requested = add_cabin!(setup, name: "Concierge", code: "C1", inventory_mode: "on_request")
    deposit = create_deposit!(setup, pools: [ blocked, requested ], rate_minor_units: 5_000)

    evaluated = SupplierDepositAmountEvaluator.call(
      definition: deposit,
      version: setup[:version].reload,
      arrangement: setup[:arrangement],
      mode: :preview
    )

    assert_equal false, evaluated[:quantity_not_tracked]
    assert_equal 40_000, evaluated[:amount_minor_units]
    assert_equal 8, evaluated.dig(:inputs, "quantity")
    assert_equal [ requested.id ], evaluated.dig(:inputs, "excluded_pools").map { |row| row["capacity_pool_id"] }
    assert_nil setup[:version].capacity_pool_definitions.find_by!(capacity_pool_id: requested.id).proposed_opening_quantity

    activate!(setup)
    tranche = deposit.reload.supplier_deposit_requirement_tranches.sole
    assert_equal 40_000, tranche.initial_amount_minor_units
    assert_equal 1, SupplierCommitment.where(
      supplier_arrangement: setup[:arrangement],
      opening_kind: "deposit_requirement"
    ).count
  end

  test "an all nonnumeric deposit is quantity not tracked and does not block or materialize" do
    setup = create_sailing!
    requested = add_cabin!(setup, name: "Concierge", code: "C1", inventory_mode: "on_request")
    external = add_cabin!(setup, name: "Suite", code: "S1", inventory_mode: "externally_managed")
    deposit = create_deposit!(setup, pools: [ requested, external ], rate_minor_units: 5_000)
    version = setup[:version].reload

    evaluated = SupplierDepositAmountEvaluator.call(
      definition: deposit,
      version: version,
      arrangement: setup[:arrangement],
      mode: :preview
    )

    assert_equal true, evaluated[:quantity_not_tracked]
    assert_nil evaluated[:amount_minor_units]
    assert_equal false, evaluated.dig(:inputs, "quantity_tracked")

    preview = PreviewCruiseDepositsAndDeadlinesActivation.call(
      agency: @agency,
      arrangement: setup[:arrangement],
      version: version,
      version_lock_version: version.lock_version
    )
    row = preview.rows.find { |candidate| candidate.kind == "deposit" }
    assert_equal "ready", preview.status
    assert_empty preview.unique_blockers
    assert_equal "Quantity not tracked", row.amount_sentence
    assert_equal false, row.will_open_commitment?

    before_tranches = SupplierDepositRequirementTranche.count
    before_commitments = SupplierCommitment.where(opening_kind: "deposit_requirement").count
    activate!(setup)
    assert_equal before_tranches, SupplierDepositRequirementTranche.count
    assert_equal before_commitments, SupplierCommitment.where(opening_kind: "deposit_requirement").count

    arrangement = setup[:arrangement]
    RebuildSupplierAttentionProjectionAlreadyLocked.new(
      agency: @agency,
      arrangement: arrangement
    ).call
    assert_not SupplierAttentionFinding.exists?(
      supplier_arrangement: arrangement,
      detector_key: "deposit_calculation_incomplete"
    )
  end

  private

  def create_sailing!
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops #{SecureRandom.hex(3)}")
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
    {
      arrangement: arrangement,
      version: version,
      item: arrangement.arrangement_items.sole,
      provider: provider
    }
  end

  def add_cabin!(setup, name:, code:, inventory_mode:, quantity: nil)
    pool_attributes = {
      inventory_mode: inventory_mode,
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed cabin terms"
    }
    pool_attributes[:proposed_opening_quantity] = quantity if quantity

    result = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: setup[:arrangement],
      resource_attributes: {
        name: name,
        supplier_code: code,
        maximum_occupancy: 3
      },
      pool_attributes: pool_attributes,
      version_lock_version: setup[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    result.record.pool
  end

  def create_deposit!(setup, pools:, rate_minor_units:)
    version = setup[:version].reload
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: version,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: rate_minor_units,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-10-13" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pools.map { |pool| pool_coverage(version, pool) }
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    version.supplier_deposit_requirement_definitions.order(:position).last
  end

  def pool_coverage(version, pool)
    definition = version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    {
      capacity_pool_id: pool.id,
      arrangement_item_id: definition.arrangement_item_id,
      service_occurrence_id: definition.service_occurrence_id,
      supplier_resource_id: definition.supplier_resource_id
    }
  end

  def activate!(setup)
    arrangement = setup[:arrangement]
    version = setup[:version].reload
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )
    satisfy_cruise_activation_gate!(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      version: version
    )
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      version: version,
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version,
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
end
