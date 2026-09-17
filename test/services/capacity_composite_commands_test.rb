require "test_helper"

class CapacityCompositeCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "M3D.0 Capacity composites")
    @contractor = create_capacity_supplier(@agency, "Composite contractor")
    @provider = create_capacity_supplier(@agency, "Composite provider")
  end

  test "bulk classification changes the submitted pair set once and replays from the exact version" do
    graph = create_capacity_graph
    second_resource = add_resource(graph, "Second resource")
    decisions = [
      decision(graph[:occurrence], graph[:resource], "pooled"),
      decision(graph[:occurrence], second_resource, "not_applicable")
    ]
    submitted_lock = graph[:version].lock_version

    result = BulkClassifyCapacityPairs.new(
      agency: @agency,
      actor: @actor,
      item: graph[:item],
      decisions: decisions,
      version_lock_version: submitted_lock,
      idempotency_key: "bulk-capacity-1"
    ).call

    assert_equal :updated, result.status
    assert_equal %w[not_applicable pooled], result.record.map(&:classification).sort
    key = AgencyCommandIdempotencyKey.find_by!(command_name: "BulkClassifyCapacityPairs", idempotency_key: "bulk-capacity-1")
    assert_equal "SupplierArrangementVersion", key.result_record_type
    assert_equal graph[:version].id, key.result_record_id

    replay = BulkClassifyCapacityPairs.new(
      agency: @agency,
      actor: @actor,
      item: graph[:item],
      decisions: decisions.reverse,
      version_lock_version: submitted_lock,
      idempotency_key: "bulk-capacity-1"
    ).call
    assert_equal :replayed, replay.status
    assert_equal result.record.map(&:id).sort, replay.record.map(&:id).sort
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.capacity_pairs_bulk_classified",
      subject_id: graph[:arrangement].id
    ).count
    assert_equal 0, AuditEvent.where(
      action: "supplier_arrangement.capacity_pair_classified",
      subject_id: graph[:arrangement].id
    ).count
  end

  test "bulk classification enforces optimistic lock and idempotency fingerprint" do
    graph = create_capacity_graph
    decisions = [ decision(graph[:occurrence], graph[:resource], "pooled") ]

    stale = assert_raises(AgencyCommand::Error) do
      BulkClassifyCapacityPairs.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        decisions: decisions,
        version_lock_version: graph[:version].lock_version - 1,
        idempotency_key: "bulk-stale"
      ).call
    end
    assert_equal :conflict, stale.code
    assert_empty graph[:version].capacity_pair_definitions

    BulkClassifyCapacityPairs.new(
      agency: @agency,
      actor: @actor,
      item: graph[:item],
      decisions: decisions,
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: "bulk-fingerprint"
    ).call
    conflict = assert_raises(AgencyCommand::Error) do
      BulkClassifyCapacityPairs.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        decisions: [ decision(graph[:occurrence], graph[:resource], "not_applicable") ],
        version_lock_version: graph[:version].reload.lock_version,
        idempotency_key: "bulk-fingerprint"
      ).call
    end
    assert_equal :conflict, conflict.code
    assert_equal "pooled", graph[:version].capacity_pair_definitions.sole.classification
  end

  test "pair Pool setup is atomic idempotent and emits only its composite audit" do
    graph = create_capacity_graph
    submitted_lock = graph[:version].lock_version
    attributes = pool_attributes

    created = ConfigureCapacityPairWithPool.new(
      agency: @agency,
      actor: @actor,
      item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      pool_attributes: attributes,
      version_lock_version: submitted_lock,
      idempotency_key: "pair-pool-1"
    ).call
    assert_equal :created, created.status
    pair = graph[:version].capacity_pair_definitions.sole
    assert_predicate pair, :pooled?
    assert_equal created.record.id, pair.capacity_pool_definitions.sole.capacity_pool_id

    replay = ConfigureCapacityPairWithPool.new(
      agency: @agency,
      actor: @actor,
      item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      pool_attributes: attributes,
      version_lock_version: submitted_lock,
      idempotency_key: "pair-pool-1"
    ).call
    assert_equal :replayed, replay.status
    assert_equal created.record.id, replay.record.id
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.capacity_pair_pool_configured",
      subject_id: graph[:arrangement].id
    ).count
    assert_equal 0, AuditEvent.where(
      action: %w[supplier_arrangement.capacity_pair_classified supplier_arrangement.capacity_pool_created],
      subject_id: graph[:arrangement].id
    ).count
  end

  test "pair Pool setup rolls classification back when the Pool definition is invalid" do
    graph = create_capacity_graph
    invalid_attributes = pool_attributes.merge(
      evidence_kind: "",
      evidence_on: "",
      evidence_reference_note: "",
      evidence_external_reference: "orphan-reference"
    )

    assert_raises(AgencyCommand::Error) do
      ConfigureCapacityPairWithPool.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        service_occurrence: graph[:occurrence],
        supplier_resource: graph[:resource],
        pool_attributes: invalid_attributes,
        version_lock_version: graph[:version].lock_version,
        idempotency_key: "pair-pool-invalid"
      ).call
    end
    assert_empty graph[:version].capacity_pair_definitions
    assert_empty graph[:arrangement].capacity_pools
    assert_not AgencyCommandIdempotencyKey.exists?(
      command_name: "ConfigureCapacityPairWithPool",
      idempotency_key: "pair-pool-invalid"
    )
    assert_not AuditEvent.exists?(
      action: "supplier_arrangement.capacity_pair_pool_configured",
      subject_id: graph[:arrangement].id
    )
  end

  test "pair Pool setup enforces the submitted version lock" do
    graph = create_capacity_graph

    error = assert_raises(AgencyCommand::Error) do
      ConfigureCapacityPairWithPool.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        service_occurrence: graph[:occurrence],
        supplier_resource: graph[:resource],
        pool_attributes: pool_attributes,
        version_lock_version: graph[:version].lock_version - 1,
        idempotency_key: "pair-pool-stale"
      ).call
    end
    assert_equal :conflict, error.code
    assert_empty graph[:version].capacity_pair_definitions
    assert_empty graph[:arrangement].capacity_pools
  end

  test "composites reject another agency graph and viewer actor" do
    other = agencies(:cove)
    other_departure = create_capacity_departure(other)
    other_contractor = create_capacity_supplier(other, "Other contractor")
    other_provider = create_capacity_supplier(other, "Other provider")
    graph = create_capacity_graph(
      agency: other,
      departure: other_departure,
      contractor: other_contractor,
      provider: other_provider
    )

    assert_raises(ActiveRecord::RecordNotFound) do
      BulkClassifyCapacityPairs.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        decisions: [ decision(graph[:occurrence], graph[:resource], "pooled") ],
        version_lock_version: graph[:version].lock_version,
        idempotency_key: "cross-agency"
      ).call
    end
    assert_raises(ActiveRecord::RecordNotFound) do
      ConfigureCapacityPairWithPool.new(
        agency: @agency,
        actor: @actor,
        item: graph[:item],
        service_occurrence: graph[:occurrence],
        supplier_resource: graph[:resource],
        pool_attributes: pool_attributes,
        version_lock_version: graph[:version].lock_version,
        idempotency_key: "cross-agency-pool"
      ).call
    end

    local = create_capacity_graph(prefix: "Viewer")
    unauthorized = assert_raises(AgencyCommand::Error) do
      ConfigureCapacityPairWithPool.new(
        agency: @agency,
        actor: agency_users(:harbor_viewer),
        item: local[:item],
        service_occurrence: local[:occurrence],
        supplier_resource: local[:resource],
        pool_attributes: pool_attributes,
        version_lock_version: local[:version].lock_version,
        idempotency_key: "viewer-pool"
      ).call
    end
    assert_equal :unauthorized, unauthorized.code
  end

  private

  def add_resource(graph, name)
    resource = graph[:item].supplier_resources.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement]
    )
    graph[:version].supplier_resource_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      supplier_resource: resource,
      name: name,
      position: 2
    )
    resource
  end

  def decision(occurrence, resource, classification)
    {
      service_occurrence_id: occurrence.id,
      supplier_resource_id: resource.id,
      classification: classification
    }
  end

  def pool_attributes
    {
      inventory_mode: "block",
      measurement_basis: "resource_units",
      label: "First Pool",
      unit_label: "rooms",
      proposed_opening_quantity: 8,
      evidence_kind: "contract",
      evidence_on: "2026-05-01",
      evidence_reference_note: "Supplier contract"
    }
  end
end
