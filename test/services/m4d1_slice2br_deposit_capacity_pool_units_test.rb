# frozen_string_literal: true

require "test_helper"

class M4d1Slice2brDepositCapacityPoolUnitsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "2BR Supplier")
    @departure = create_capacity_departure(@agency, name: "2BR Departure", status: "draft")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current,
      starts_on: Date.new(2027, 8, 1),
      ends_on: Date.new(2027, 8, 8),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "2BR", capacity_management: "managed"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_ready_cost!
    create_confirmation_trigger!
    @pool = add_pool!(quantity: 10)
  end

  test "capacity_pool_units preview uses proposed opening and materialize uses established" do
    definition = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: [ {
        arrangement_item_id: @graph[:item].id,
        service_occurrence_id: @graph[:occurrence].id,
        supplier_resource_id: @graph[:resource].id,
        capacity_pool_id: @pool.id
      } ]
    )

    preview = SupplierDepositAmountEvaluator.call(
      definition:, version: @version, arrangement: @arrangement, mode: :preview
    )
    assert_equal 50_000, preview[:amount_minor_units]
    assert_equal "proposed_opening", preview[:inputs]["quantity_phase"]
    assert_equal 10, preview[:inputs]["quantity"]

    error = assert_raises(SupplierDepositAmountEvaluator::IncompleteCalculation) do
      SupplierDepositAmountEvaluator.call(
        definition:, version: @version, arrangement: @arrangement, mode: :materialize
      )
    end
    assert_match(/established/i, error.message)

    activate!
    definition.reload
    materialized = SupplierDepositAmountEvaluator.call(
      definition:, version: @version.reload, arrangement: @arrangement, mode: :materialize
    )
    assert_equal 50_000, materialized[:amount_minor_units]
    assert_equal "established_opening", materialized[:inputs]["quantity_phase"]
    assert_equal 1, materialized[:inputs]["sources"].size
    assert_equal @pool.id, materialized[:inputs]["sources"].sole["capacity_pool_id"]
  end

  test "quantity-derived cumulative reevaluates after retained capacity decreases" do
    initial = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage
    )
    final = create_deposit!(
      amount_shape: "cumulative_target",
      rate_minor_units: 50_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage,
      contributor_definition_ids: [ initial.id ]
    )
    activate!
    final_tranche = SupplierDepositRequirementTranche.find_by!(
      supplier_deposit_requirement_definition: final
    )
    assert_equal 450_000, final_tranche.current_amount_minor_units

    projection = @pool.capacity_projection
    ReleaseCapacity.new(
      agency: @agency, actor: @actor, pool: @pool, quantity: 2,
      projection_lock_version: projection.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        evidence_kind: "contract", evidence_on: Date.current,
        evidence_reference_note: "Option release", override: false
      }
    ).call

    final_tranche.reload
    assert_equal 350_000, final_tranche.current_amount_minor_units,
      "$500 × 8 retained − $50 × 10 credited after releasing 2"
    assert final_tranche.supplier_deposit_requirement_tranche_components
      .exists?(component_kind: "adjustment_decrease")
  end

  test "contributor credit includes post-attestation increments" do
    initial = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage
    )
    final = create_deposit!(
      amount_shape: "cumulative_target",
      rate_minor_units: 50_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage,
      contributor_definition_ids: [ initial.id ]
    )
    activate!
    initial_tranche = SupplierDepositRequirementTranche.find_by!(
      supplier_deposit_requirement_definition: initial
    )
    final_tranche = SupplierDepositRequirementTranche.find_by!(
      supplier_deposit_requirement_definition: final
    )
    commitment = SupplierCommitment.find_by!(supplier_deposit_requirement_tranche: initial_tranche)
    AttestSupplierDepositHandledExternally.new(
      agency: @agency, actor: @actor, commitment:,
      note: "Handled outside", confirmed_complete: true,
      idempotency_key: SecureRandom.uuid
    ).call
    AdjustSupplierDepositRequirementTranche.new(
      agency: @agency, actor: @actor, tranche: initial_tranche.reload,
      amount_delta_minor_units: 5_000,
      note: "One more cabin",
      idempotency_key: SecureRandom.uuid
    ).call

    ReevaluateQuantityDerivedDepositCumulativeAlreadyLocked.new(
      agency: @agency, actor: @actor, arrangement: @arrangement,
      version: @version.reload, at: Time.current
    ).call

    final_tranche.reload
    assert_equal 445_000, final_tranche.current_amount_minor_units,
      "$500 × 10 − ($1,200 initial + $50 increment)"
  end

  test "capacity_pool_units coverage requires explicit capacity_pool_id" do
    error = assert_raises(AgencyCommand::Error) do
      create_deposit!(
        amount_shape: "quantity_times_rate",
        rate_minor_units: 5_000,
        quantity_basis: "capacity_pool_units",
        coverage_links: [ {
          arrangement_item_id: @graph[:item].id,
          supplier_resource_id: @graph[:resource].id
        } ]
      )
    end
    assert_match(/capacity_pool_id/i, error.message)
  end

  test "contributor must be earlier capacity_pool_units quantity definition" do
    fixed = create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 1_000
    )
    error = assert_raises(AgencyCommand::Error) do
      create_deposit!(
        amount_shape: "cumulative_target",
        rate_minor_units: 50_000,
        quantity_basis: "capacity_pool_units",
        coverage_links: pool_coverage,
        contributor_definition_ids: [ fixed.id ]
      )
    end
    assert_match(/capacity_pool_units contributors/i, error.message)
  end

  test "retained evaluation refreshes projection before snapshotting amount" do
    initial = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage
    )
    final = create_deposit!(
      amount_shape: "cumulative_target",
      rate_minor_units: 50_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage,
      contributor_definition_ids: [ initial.id ]
    )
    activate!
    projection = @pool.capacity_projection
    ReleaseCapacity.new(
      agency: @agency, actor: @actor, pool: @pool, quantity: 2,
      projection_lock_version: projection.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        evidence_kind: "contract", evidence_on: Date.current,
        evidence_reference_note: "Immediate option", override: false
      }
    ).call

    projection = @pool.capacity_projection.reload
    assert_equal 8, projection.current_supplier_capacity
    # Corrupt the cached current so only a refresh restores the ledger truth.
    projection.update_columns(current_supplier_capacity: 10, rebuilt_at: 1.hour.ago)

    evaluated = SupplierDepositAmountEvaluator.call(
      definition: final.reload, version: @version.reload,
      arrangement: @arrangement, mode: :materialize, at: Time.current
    )
    assert_equal 8, @pool.capacity_projection.reload.current_supplier_capacity
    assert_equal 350_000, evaluated[:amount_minor_units],
      "Evaluator refresh must apply released capacity before retained snapshot"
  end

  test "legacy fixed cumulative still credits earlier defs by position" do
    create_deposit!(
      amount_shape: "fixed_amount",
      fixed_amount_minor_units: 5_000
    )
    create_deposit!(
      amount_shape: "cumulative_target",
      target_amount_minor_units: 50_000
    )
    activate!
    final = SupplierDepositRequirementTranche.find_by!(
      supplier_arrangement_version: @version, amount_shape: "cumulative_target"
    )
    assert_equal 45_000, final.current_amount_minor_units
  end

  test "missing retained projection blocks quantity-derived cumulative" do
    initial = create_deposit!(
      amount_shape: "quantity_times_rate",
      rate_minor_units: 5_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage
    )
    final = create_deposit!(
      amount_shape: "cumulative_target",
      rate_minor_units: 50_000,
      quantity_basis: "capacity_pool_units",
      coverage_links: pool_coverage,
      contributor_definition_ids: [ initial.id ]
    )
    activate!
    CapacityProjection.where(capacity_pool_id: @pool.id).delete_all

    error = assert_raises(SupplierDepositAmountEvaluator::IncompleteCalculation) do
      SupplierDepositAmountEvaluator.call(
        definition: final.reload, version: @version.reload,
        arrangement: @arrangement, mode: :materialize
      )
    end
    assert_match(/projection/i, error.message)
  end

  private

  def pool_coverage
    [ {
      arrangement_item_id: @graph[:item].id,
      service_occurrence_id: @graph[:occurrence].id,
      supplier_resource_id: @graph[:resource].id,
      capacity_pool_id: @pool.id
    } ]
  end

  def create_ready_cost!
    SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      charging_supplier: @supplier,
      label: "Ready", position: 1
    ).tap do |source|
      SupplierCostDefinition.create!(
        agency: @agency, departure: @departure,
        supplier_arrangement: @arrangement,
        supplier_arrangement_version: @version,
        supplier_cost_source: source,
        stage: "contracted", status: "forecast_ready", mode: "zero_cost",
        zero_cost_reason: "Included", currency: "USD",
        forecast_ready_by: @actor, forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:#{SecureRandom.hex(8)}",
        readiness_provenance: "Signed"
      )
    end
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

  def add_pool!(quantity:)
    pair = classify_capacity_graph_pair(@graph)
    pool = CapacityPool.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      supplying_supplier: @supplier,
      inventory_mode: "block", measurement_basis: "resource_units",
      effective_time_zone: "America/New_York"
    )
    CapacityPoolDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      capacity_pair_definition: pair, capacity_pool: pool,
      label: "Block", normalized_label: "block",
      unit_label: "cabins", proposed_opening_quantity: quantity,
      evidence_kind: "contract", evidence_on: Date.current,
      evidence_reference_note: "Block", override: false, position: 1
    )
    pool
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
        cost_links: [],
        contributor_definition_ids: []
      }.merge(attrs),
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def activate!
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
