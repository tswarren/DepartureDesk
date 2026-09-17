require "test_helper"

class SupplierArrangementSuccessorsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "Successor Supplier")
    @departure = create_capacity_departure(@agency, name: "Successor Departure")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Successor",
      capacity_management: "managed"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    create_capacity_terms
    create_cost_graph
    create_trigger
    @first_activation = activate(@version).record
  end

  test "successor copies an independent complete graph with exact lineage" do
    successor = create_successor.record

    assert_equal 2, successor.version_number
    assert_equal @version.id, successor.copied_from_id
    assert_equal "draft", successor.status
    assert_equal "activated", @version.reload.status

    lineage_families.each do |model|
      originals = model.where(supplier_arrangement_version_id: @version.id).order(:id)
      copies = model.where(supplier_arrangement_version_id: successor.id).order(:id)
      assert_equal originals.count, copies.count, model.name
      assert_equal originals.pluck(:id).sort, copies.pluck(:copied_from_id).sort, model.name
    end

    copied_item = successor.arrangement_item_definitions.sole
    copied_item.update!(name: "Revised independent item")
    assert_equal "Successor item", @version.arrangement_item_definitions.sole.reload.name
    assert_equal "forecast_ready", successor.supplier_cost_definitions.contracted.sole.status
    assert SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: successor
    ).call.ready?
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.successor_created", subject_id: @arrangement.id
    ).count
  end

  test "successor activation supersedes predecessor and carries capacity atomically" do
    successor = create_successor.record
    event_ids = @graph[:pool].capacity_events.pluck(:id)

    activation = activate(successor).record

    assert_equal "successor", activation.activation_kind
    assert_equal @version.id, activation.predecessor_version_id
    assert_equal @first_activation.id, activation.predecessor_activation_id
    assert_equal "superseded", @version.reload.status
    assert_equal "activated", successor.reload.status
    assert_equal successor.id, @arrangement.reload.governing_version_id
    assert_equal event_ids, @graph[:pool].capacity_events.pluck(:id)
    assert_equal "carried", activation.capacity_entries.sole.entry_kind
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.successor_activated", subject_id: @arrangement.id
    ).count
  end

  test "abandoning a successor retains the active arrangement and governing predecessor" do
    successor = create_successor.record

    AbandonSupplierArrangement.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      reason: "Terms will not change",
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: successor.reload.lock_version
    ).call

    assert_equal "abandoned", successor.reload.status
    assert_equal "active", @arrangement.reload.status
    assert_equal @version.id, @arrangement.governing_version_id
    assert_equal "activated", @version.reload.status
    audit = AuditEvent.where(
      action: "supplier_arrangement.abandoned", subject_id: @arrangement.id
    ).last
    assert_equal "successor", audit.details["abandonment_kind"]
  end

  test "a carried numeric Pool cannot be omitted while effective capacity remains" do
    successor = create_successor.record
    definition = successor.capacity_pool_definitions.sole

    error = assert_raises(AgencyCommand::Error) do
      RemoveCapacityPool.new(
        agency: @agency,
        actor: @actor,
        definition: definition,
        version_lock_version: successor.lock_version,
        lock_version: definition.lock_version
      ).call
    end

    assert_equal :dependency_exists, error.code
    assert CapacityPoolDefinition.exists?(definition.id)
    assert CapacityPool.exists?(@graph[:pool].id)
  end

  private

  def create_successor
    CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def activate(version)
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      version: version,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier confirmed exact version #{version.version_number}",
        confirmed_without_identifier_reason: "No identifier issued"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    ).call
  end

  def create_capacity_terms
    pair = classify_capacity_graph_pair(@graph)
    pool = CapacityPool.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      supplying_supplier: @supplier,
      inventory_mode: "block",
      measurement_basis: "resource_units",
      effective_time_zone: "America/New_York"
    )
    definition = CapacityPoolDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @graph[:item],
      service_occurrence: @graph[:occurrence],
      supplier_resource: @graph[:resource],
      capacity_pair_definition: pair,
      capacity_pool: pool,
      label: "Eight rooms",
      normalized_label: "eight rooms",
      unit_label: "rooms",
      proposed_opening_quantity: 8,
      evidence_kind: "contract",
      evidence_on: Date.current,
      evidence_reference_note: "Signed room block",
      position: 1
    )
    @graph.merge!(pair: pair, pool: pool, pool_definition: definition)
  end

  def create_cost_graph
    owner = {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version
    }
    category = SupplierCostParticipantCategory.create!(
      owner.merge(arrangement_item: @graph[:item], label: "Adult", position: 1)
    )
    assumption = SupplierCostUsageAssumption.create!(
      owner.merge(arrangement_item: @graph[:item], expected_resource_units: 8)
    )
    profile = SupplierCostOccupancyProfile.create!(
      owner.merge(
        arrangement_item: @graph[:item],
        supplier_cost_usage_assumption: assumption,
        label: "Double",
        resource_unit_count: 8,
        position: 1
      )
    )
    SupplierCostOccupancyProfilePosition.create!(
      owner.merge(
        arrangement_item: @graph[:item],
        supplier_cost_usage_assumption: assumption,
        supplier_cost_occupancy_profile: profile,
        participant_category: category,
        occupancy_position: 1
      )
    )
    source = SupplierCostSource.create!(
      owner.merge(
        arrangement_item: @graph[:item],
        charging_supplier: @supplier,
        label: "Room cost",
        position: 1
      )
    )
    ready = SupplierCostDefinition.create!(
      owner.merge(
        supplier_cost_source: source,
        stage: "contracted",
        status: "working",
        mode: "zero_cost",
        zero_cost_reason: "Included",
        currency: "USD"
      )
    )
    ready.update!(
      status: "forecast_ready",
      forecast_ready_by: @actor,
      forecast_ready_at: Time.current,
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(ready),
      readiness_provenance: "Signed terms"
    )
    estimate = SupplierCostDefinition.create!(
      owner.merge(
        supplier_cost_source: source,
        stage: "estimate",
        status: "working",
        mode: "calculated",
        currency: "USD"
      )
    )
    fixed = SupplierCostComponent.create!(
      owner.merge(
        supplier_cost_definition: estimate,
        label: "Base",
        economic_role: "supplier_charge",
        calculation_kind: "fixed",
        amount_minor_units: 10_000,
        position: 1
      )
    )
    percentage = SupplierCostComponent.create!(
      owner.merge(
        supplier_cost_definition: estimate,
        label: "Tax",
        economic_role: "supplier_charge",
        calculation_kind: "percentage",
        rate: BigDecimal("0.1"),
        percentage_treatment: "additive",
        position: 2
      )
    )
    SupplierCostComponentBase.create!(
      owner.merge(
        supplier_cost_definition: estimate,
        supplier_cost_component: percentage,
        base_component: fixed,
        direction: "add",
        position: 1
      )
    )
  end

  def create_trigger
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Eight guaranteed rooms",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )
  end

  def lineage_families
    [
      ArrangementItemDefinition,
      ServiceOccurrenceDefinition,
      SupplierResourceDefinition,
      CapacityPairDefinition,
      CapacityPoolDefinition,
      SupplierCostSource,
      SupplierCostDefinition,
      SupplierCostComponent,
      SupplierCostComponentBase,
      SupplierCostParticipantCategory,
      SupplierCostUsageAssumption,
      SupplierCostOccupancyProfile,
      SupplierCostOccupancyProfilePosition,
      SupplierCommitmentTriggerDefinition
    ]
  end
end
