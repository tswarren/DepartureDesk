require "test_helper"

class CapacityDraftCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M3B Draft Capacity")
    @contractor = create_capacity_supplier(@agency, "M3B Contractor")
    @provider = create_capacity_supplier(@agency, "M3B Provider")
  end

  test "set item capacity management managed unmanaged and undecided" do
    graph = create_capacity_graph(capacity_management: nil)
    definition = graph[:item_definition]

    managed = SetItemCapacityManagement.new(
      agency: @agency,
      actor: @staff,
      definition: definition,
      capacity_management: "managed",
      lock_version: definition.lock_version
    ).call
    assert_equal :updated, managed.status
    assert_equal "managed", definition.reload.capacity_management

    undecided = SetItemCapacityManagement.new(
      agency: @agency,
      actor: @staff,
      definition: definition,
      capacity_management: nil,
      lock_version: definition.lock_version
    ).call
    assert_equal :updated, undecided.status
    assert_nil definition.reload.capacity_management

    unmanaged = SetItemCapacityManagement.new(
      agency: @agency,
      actor: @staff,
      definition: definition,
      capacity_management: "unmanaged",
      lock_version: definition.lock_version
    ).call
    assert_equal :updated, unmanaged.status
    assert_equal "unmanaged", definition.reload.capacity_management
  end

  test "unmanaged capacity management fails while draft structure exists" do
    graph = create_capacity_graph
    classify_pair(graph)

    error = assert_raises(AgencyCommand::Error) do
      SetItemCapacityManagement.new(
        agency: @agency,
        actor: @actor,
        definition: graph[:item_definition],
        capacity_management: "unmanaged",
        lock_version: graph[:item_definition].lock_version
      ).call
    end
    assert_equal :invalid_state, error.code
    assert_equal "managed", graph[:item_definition].reload.capacity_management
  end

  test "classify capacity pair as pooled and not applicable" do
    graph = create_capacity_graph

    pooled = classify_pair(graph, classification: "pooled")
    assert_equal :created, pooled.status
    pair = pooled.record
    assert_equal "pooled", pair.classification

    not_applicable = classify_pair(graph, classification: "not_applicable")
    assert_equal :updated, not_applicable.status
    assert_equal "not_applicable", pair.reload.classification
    assert_equal 2, AuditEvent.where(action: "supplier_arrangement.capacity_pair_classified", subject_id: graph[:arrangement].id).count
  end

  test "create numeric and on request capacity pools" do
    graph = create_capacity_graph
    pair = classify_pair(graph).record

    numeric = create_pool(pair, key: "numeric-pool", quantity: 8)
    numeric_definition = numeric.record.definitions.sole
    assert_equal :created, numeric.status
    assert_equal "block", numeric.record.inventory_mode
    assert_equal "resource_units", numeric.record.measurement_basis
    assert_equal @provider.id, numeric.record.supplying_supplier_id
    assert_equal graph[:occurrence_definition].time_zone, numeric.record.effective_time_zone
    assert_equal 8, numeric_definition.proposed_opening_quantity
    assert_equal "Cabin block", numeric_definition.label
    assert_equal "contract", numeric_definition.evidence_kind

    on_request = create_pool(
      pair.reload,
      key: "request-pool",
      inventory_mode: "on_request",
      quantity: nil,
      label: nil,
      unit_label: "cabins",
      evidence: false
    )
    on_request_definition = on_request.record.definitions.sole
    assert_equal :created, on_request.status
    assert_equal "on_request", on_request.record.inventory_mode
    assert_nil on_request_definition.proposed_opening_quantity
    assert_equal "on request cabins", on_request_definition.label
    assert_equal "cabins", on_request_definition.unit_label
  end

  test "create capacity pool replays with original stale version lock" do
    graph = create_capacity_graph
    pair = classify_pair(graph).record
    submitted_lock = graph[:version].reload.lock_version
    attrs = pool_attributes(quantity: 8, label: "Replay pool")

    created = CreateCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pair: pair,
      version_lock_version: submitted_lock,
      idempotency_key: "pool-replay",
      attributes: attrs
    ).call
    assert_equal :created, created.status
    assert graph[:version].reload.lock_version > submitted_lock

    replayed = CreateCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pair: pair.reload,
      version_lock_version: submitted_lock,
      idempotency_key: "pool-replay",
      attributes: attrs
    ).call
    assert_equal :replayed, replayed.status
    assert_equal created.record.id, replayed.record.id
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.capacity_pool_created", subject_id: graph[:arrangement].id).count
  end

  test "update reorder remove pools and remove pair classification" do
    graph = create_capacity_graph
    pair = classify_pair(graph).record
    first = create_pool(pair, key: "first-pool", label: "First pool").record
    second = create_pool(pair.reload, key: "second-pool", label: "Second pool", quantity: 5).record
    first_definition = first.definitions.sole
    second_definition = second.definitions.sole

    updated = UpdateCapacityPool.new(
      agency: @agency,
      actor: @actor,
      definition: first_definition,
      lock_version: first_definition.lock_version,
      attributes: { label: "Updated pool", notes: "Supplier adjusted wording", unit_label: "rooms", proposed_opening_quantity: 9 }
    ).call
    assert_equal :updated, updated.status
    assert_equal "Updated pool", first_definition.reload.label
    assert_equal 9, first_definition.proposed_opening_quantity

    reordered = ReorderCapacityPools.new(
      agency: @agency,
      actor: @actor,
      pair: pair.reload,
      version_lock_version: graph[:version].reload.lock_version,
      capacity_pool_ids: [ second.id, first.id ]
    ).call
    assert_equal :updated, reordered.status
    assert_equal [ second.id, first.id ], pair.capacity_pool_definitions.order(:position).pluck(:capacity_pool_id)

    RemoveCapacityPool.new(
      agency: @agency,
      actor: @actor,
      definition: second_definition.reload,
      version_lock_version: graph[:version].reload.lock_version,
      lock_version: second_definition.lock_version
    ).call
    assert_not CapacityPool.exists?(second.id)

    RemoveCapacityPool.new(
      agency: @agency,
      actor: @actor,
      definition: first_definition.reload,
      version_lock_version: graph[:version].reload.lock_version,
      lock_version: first_definition.lock_version
    ).call
    assert_not CapacityPool.exists?(first.id)

    removed_pair = RemoveCapacityPairClassification.new(
      agency: @agency,
      actor: @actor,
      pair: pair.reload,
      version_lock_version: graph[:version].reload.lock_version,
      lock_version: pair.lock_version
    ).call
    assert_equal :updated, removed_pair.status
    assert_not CapacityPairDefinition.exists?(pair.id)
  end

  test "departed recovery only allows managed to unmanaged after structure is gone" do
    graph = create_capacity_graph
    pair = classify_pair(graph).record
    pool = create_pool(pair, key: "departed-pool").record
    definition = pool.definitions.sole
    Departure.where(id: @departure.id).update_all(
      status: "departed",
      departure_reference: "D-999001",
      first_activated_at: Time.current,
      departed_at: Time.current,
      updated_at: Time.current
    )

    with_structure = assert_raises(AgencyCommand::Error) do
      SetItemCapacityManagement.new(
        agency: @agency,
        actor: @actor,
        definition: graph[:item_definition].reload,
        capacity_management: "unmanaged",
        lock_version: graph[:item_definition].lock_version
      ).call
    end
    assert_equal :invalid_state, with_structure.code

    expansion = assert_raises(AgencyCommand::Error) do
      classify_pair(graph, classification: "not_applicable")
    end
    assert_equal :invalid_state, expansion.code

    RemoveCapacityPool.new(
      agency: @agency,
      actor: @actor,
      definition: definition.reload,
      version_lock_version: graph[:version].reload.lock_version,
      lock_version: definition.lock_version
    ).call
    RemoveCapacityPairClassification.new(
      agency: @agency,
      actor: @actor,
      pair: pair.reload,
      version_lock_version: graph[:version].reload.lock_version,
      lock_version: pair.lock_version
    ).call

    unmanaged = SetItemCapacityManagement.new(
      agency: @agency,
      actor: @actor,
      definition: graph[:item_definition].reload,
      capacity_management: "unmanaged",
      lock_version: graph[:item_definition].lock_version
    ).call
    assert_equal :updated, unmanaged.status
    assert_equal "unmanaged", graph[:item_definition].reload.capacity_management

    [ nil, "managed" ].each do |next_value|
      error = assert_raises(AgencyCommand::Error) do
        SetItemCapacityManagement.new(
          agency: @agency,
          actor: @actor,
          definition: graph[:item_definition].reload,
          capacity_management: next_value,
          lock_version: graph[:item_definition].lock_version
        ).call
      end
      assert_equal :invalid_state, error.code
    end
  end

  test "update arrangement item leaves capacity management unchanged" do
    graph = create_capacity_graph
    definition = graph[:item_definition]

    UpdateArrangementItem.new(
      agency: @agency,
      actor: @actor,
      definition: definition,
      lock_version: definition.lock_version,
      attributes: {
        name: "Renamed capacity item",
        category: definition.category,
        other_category_label: definition.other_category_label,
        description: definition.description,
        default_service_provider_id: @provider.id,
        capacity_management: "unmanaged"
      }
    ).call

    assert_equal "Renamed capacity item", definition.reload.name
    assert_equal "managed", definition.capacity_management
  end

  test "m3a removals require capacity structure cleanup first" do
    graph = create_capacity_graph
    pair = classify_pair(graph).record
    create_pool(pair, key: "removal-blocker-pool")

    occurrence_error = assert_raises(AgencyCommand::Error) do
      RemoveServiceOccurrence.new(
        agency: @agency,
        actor: @actor,
        occurrence: graph[:occurrence],
        version_lock_version: graph[:version].reload.lock_version
      ).call
    end
    assert_equal :dependency_exists, occurrence_error.code
    assert ServiceOccurrence.exists?(graph[:occurrence].id)

    resource_error = assert_raises(AgencyCommand::Error) do
      RemoveSupplierResource.new(
        agency: @agency,
        actor: @actor,
        resource: graph[:resource],
        version_lock_version: graph[:version].reload.lock_version
      ).call
    end
    assert_equal :dependency_exists, resource_error.code
    assert SupplierResource.exists?(graph[:resource].id)

    item_error = assert_raises(AgencyCommand::Error) do
      RemoveArrangementItem.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        version_lock_version: graph[:version].reload.lock_version
      ).call
    end
    assert_equal :dependency_exists, item_error.code
    assert ArrangementItem.exists?(graph[:item].id)
  end

  private

  def classify_pair(graph, classification: "pooled")
    ClassifyCapacityPair.new(
      agency: @agency,
      actor: @actor,
      item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      classification: classification,
      version_lock_version: graph[:version].reload.lock_version
    ).call
  end

  def create_pool(pair, key:, inventory_mode: "block", quantity: 8, label: "Cabin block", unit_label: "cabins", evidence: true)
    CreateCapacityPool.new(
      agency: @agency,
      actor: @actor,
      pair: pair,
      version_lock_version: pair.supplier_arrangement_version.reload.lock_version,
      idempotency_key: key,
      attributes: pool_attributes(
        inventory_mode: inventory_mode,
        quantity: quantity,
        label: label,
        unit_label: unit_label,
        evidence: evidence
      )
    ).call
  end

  def pool_attributes(inventory_mode: "block", quantity: 8, label: "Cabin block", unit_label: "cabins", evidence: true)
    attrs = {
      inventory_mode: inventory_mode,
      measurement_basis: "resource_units",
      label: label,
      unit_label: unit_label,
      proposed_opening_quantity: quantity
    }
    if evidence
      attrs.merge!(
        evidence_kind: "contract",
        evidence_on: "2026-05-01",
        evidence_reference_note: "Contracted capacity"
      )
    end
    attrs
  end
end
