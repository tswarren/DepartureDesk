require "test_helper"

class CapacityConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other_agency = agencies(:cove)
    @actor = agency_users(:harbor_admin)
    @departure = @agency.departures.create!(name: "Harbor M3B Departure")
    @other_departure = @other_agency.departures.create!(name: "Cove M3B Departure")
    @contractor = create_supplier(@agency, "SUP-410001", "Harbor Contractor")
    @provider = create_supplier(@agency, "SUP-410002", "Harbor Provider")
    @other_supplier = create_supplier(@other_agency, "SUP-420001", "Cove Provider")
  end

  test "capacity tables have direct ownership UUIDv7 defaults and timestamptz columns" do
    connection = ActiveRecord::Base.connection
    tables = %w[
      capacity_pair_definitions
      capacity_pools
      capacity_pool_definitions
      capacity_events
      capacity_projections
      capacity_reconciliations
      capacity_reconciliation_resolutions
    ]

    tables.each do |table|
      columns = connection.columns(table).index_by(&:name)
      assert_equal "uuidv7()", columns.fetch("id").default_function
      assert_equal "uuid", columns.fetch("agency_id").sql_type
      assert_equal "uuid", columns.fetch("departure_id").sql_type
      assert_includes columns.fetch("created_at").sql_type, "with time zone"
      assert_includes columns.fetch("updated_at").sql_type, "with time zone"
    end

    assert_equal %w[managed unmanaged], ArrangementItemDefinition::CAPACITY_MANAGEMENT
    assert_equal %w[administrator], AccessPermission::CATALOG.fetch(:override_supplier_planning_terms)
    assert_includes AuditEvent::ACTIONS, "supplier_arrangement.capacity_reconciliation_resolved"
  end

  test "capacity management and capacity catalogs are database constrained" do
    graph = create_graph

    graph[:item_definition].update!(capacity_management: "managed")
    graph[:item_definition].update!(capacity_management: nil)

    assert_raises(ActiveRecord::StatementInvalid) do
      ArrangementItemDefinition.transaction(requires_new: true) do
        ArrangementItemDefinition.where(id: graph[:item_definition].id).update_all(capacity_management: "automatic")
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityPairDefinition.transaction(requires_new: true) do
        CapacityPairDefinition.insert!(pair_row(graph: graph, classification: "unknown"))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityPool.transaction(requires_new: true) do
        CapacityPool.insert!(pool_row(graph: graph, inventory_mode: "reserved"))
      end
    end
  end

  test "complete ownership composite foreign keys reject cross graph capacity records" do
    first = create_capacity_graph(prefix: "First")
    second = create_capacity_graph(prefix: "Second")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      CapacityPairDefinition.transaction(requires_new: true) do
        CapacityPairDefinition.insert!(pair_row(
          graph: first,
          supplier_arrangement_version_id: second[:version].id
        ))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      CapacityPoolDefinition.transaction(requires_new: true) do
        CapacityPoolDefinition.insert!(pool_definition_row(
          graph: first,
          capacity_pool_id: second[:pool].id
        ))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      CapacityEvent.transaction(requires_new: true) do
        CapacityEvent.insert!(event_row(
          graph: first,
          capacity_pool_id: second[:pool].id
        ))
      end
    end
  end

  test "cancelled occurrences cannot receive new pair classifications" do
    graph = create_graph
    graph[:occurrence].update!(status: "cancelled")

    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityPairDefinition.transaction(requires_new: true) do
        CapacityPairDefinition.insert!(pair_row(graph: graph))
      end
    end
  end

  test "pool definition labels and positions are constrained within a pair" do
    graph = create_capacity_graph

    duplicate = create_pool(graph)
    assert_raises(ActiveRecord::RecordNotUnique) do
      CapacityPoolDefinition.create!(
        pool_definition_attributes(graph: graph, pool: duplicate, position: 2)
          .merge(label: graph[:pool_definition].label, normalized_label: graph[:pool_definition].normalized_label)
      )
    end

    second_definition = CapacityPoolDefinition.create!(
      pool_definition_attributes(graph: graph, pool: duplicate, position: 2, label: "Overflow", normalized_label: "overflow")
    )

    CapacityPoolDefinition.transaction(requires_new: true) do
      graph[:pool_definition].update!(position: 2)
      second_definition.update!(position: 1)
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS capacity_pool_defs_position_unique IMMEDIATE")
    end

    assert_equal 2, graph[:pool_definition].reload.position
    assert_equal 1, second_definition.reload.position
  end

  test "event and reconciliation authority quantities and append-only triggers are enforced" do
    graph = create_capacity_graph

    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityEvent.transaction(requires_new: true) do
        CapacityEvent.insert!(event_row(graph: graph, quantity: 0))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityEvent.transaction(requires_new: true) do
        CapacityEvent.insert!(event_row(graph: graph, evidence_kind: nil, evidence_on: nil, evidence_reference_note: nil))
      end
    end

    event = CapacityEvent.create!(event_attributes(graph))
    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityEvent.transaction(requires_new: true) do
        CapacityEvent.where(id: event.id).update_all(quantity: 9)
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityEvent.transaction(requires_new: true) do
        CapacityEvent.where(id: event.id).delete_all
      end
    end

    reconciliation = CapacityReconciliation.create!(reconciliation_attributes(graph))
    assert_raises(ActiveRecord::StatementInvalid) do
      CapacityReconciliation.transaction(requires_new: true) do
        CapacityReconciliation.where(id: reconciliation.id).update_all(observed_quantity: 5)
      end
    end
  end

  test "timeline replay computes running quantity and rejects negative prefixes" do
    increase = capacity_event_double("increased", 3, 2)
    opening = capacity_event_double("established", 8, 1)
    release = capacity_event_double("released", 4, 3)

    result = CapacityTimelineReplay.new([ increase, release, opening ]).call
    assert_equal 7, result.quantity

    assert_raises(CapacityTimelineReplay::NegativeQuantity) do
      CapacityTimelineReplay.new([ release ]).call
    end
  end

  private

  def create_supplier(agency, reference, name)
    agency.suppliers.create!(
      kind: "organization",
      supplier_reference: reference,
      display_name: name,
      status: "active"
    )
  end

  def create_graph(prefix: "Graph")
    arrangement = SupplierArrangement.create!(
      agency: @agency,
      departure: @departure,
      contracting_supplier: @contractor,
      name: "#{prefix} Arrangement",
      status: "draft"
    )
    version = arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1,
      status: "draft"
    )
    item = arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    item_definition = version.arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      name: "#{prefix} item",
      category: "cruise",
      capacity_management: "managed",
      default_service_provider: @provider,
      position: 1
    )
    occurrence = item.service_occurrences.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      status: "planned"
    )
    occurrence_definition = version.service_occurrence_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      service_occurrence: occurrence,
      name: "#{prefix} occurrence",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 1),
      time_zone: "America/New_York",
      service_provider: @provider
    )
    resource = item.supplier_resources.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement
    )
    resource_definition = version.supplier_resource_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      supplier_resource: resource,
      name: "#{prefix} resource",
      position: 1
    )

    {
      arrangement: arrangement,
      version: version,
      item: item,
      item_definition: item_definition,
      occurrence: occurrence,
      occurrence_definition: occurrence_definition,
      resource: resource,
      resource_definition: resource_definition
    }
  end

  def create_capacity_graph(prefix: "Graph")
    graph = create_graph(prefix: prefix)
    pair = CapacityPairDefinition.create!(pair_attributes(graph))
    pool = create_pool(graph)
    pool_definition = CapacityPoolDefinition.create!(pool_definition_attributes(graph: graph, pool: pool, pair: pair))
    graph.merge(pair: pair, pool: pool, pool_definition: pool_definition)
  end

  def create_pool(graph)
    CapacityPool.create!(pool_attributes(graph))
  end

  def pair_attributes(graph)
    {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      classification: "pooled"
    }
  end

  def pool_attributes(graph)
    {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      supplying_supplier: @provider,
      inventory_mode: "block",
      measurement_basis: "resource_units",
      effective_time_zone: "America/New_York"
    }
  end

  def pool_definition_attributes(graph:, pool:, pair: graph[:pair], **attrs)
    {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pair_definition: pair,
      capacity_pool: pool,
      label: "Cabin block",
      normalized_label: "cabin block",
      unit_label: "cabins",
      proposed_opening_quantity: 8,
      evidence_kind: "contract",
      evidence_on: Date.new(2026, 5, 1),
      evidence_reference_note: "Contracted capacity",
      position: 1
    }.merge(attrs)
  end

  def event_attributes(graph, **attrs)
    {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pool: graph[:pool],
      supplying_supplier: @provider,
      event_type: "established",
      quantity: 8,
      measurement_basis: "resource_units",
      effective_on: Date.new(2026, 6, 1),
      effective_time_zone: "America/New_York",
      applies_at: Time.zone.parse("2026-06-01 12:00:00 UTC"),
      effective_sequence: 1,
      recorded_at: Time.zone.parse("2026-06-01 12:00:00 UTC"),
      evidence_kind: "contract",
      evidence_on: Date.new(2026, 5, 1),
      evidence_reference_note: "Contracted capacity",
      actor: @actor
    }.merge(attrs)
  end

  def reconciliation_attributes(graph, **attrs)
    {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      supplier_arrangement_version: graph[:version],
      arrangement_item: graph[:item],
      service_occurrence: graph[:occurrence],
      supplier_resource: graph[:resource],
      capacity_pool: graph[:pool],
      observed_quantity: 8,
      observed_at: Time.zone.parse("2026-06-02 12:00:00 UTC"),
      observed_time_zone: "America/New_York",
      ledger_quantity: 8,
      variance: 0,
      evidence_kind: "supplier_confirmation",
      evidence_on: Date.new(2026, 6, 2),
      evidence_reference_note: "Supplier confirmed capacity",
      actor: @actor,
      recorded_at: Time.zone.parse("2026-06-02 12:30:00 UTC")
    }.merge(attrs)
  end

  def pair_row(graph:, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      supplier_resource_id: graph[:resource].id,
      classification: "pooled",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def pool_row(graph:, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      supplier_resource_id: graph[:resource].id,
      supplying_supplier_id: @provider.id,
      inventory_mode: "block",
      measurement_basis: "resource_units",
      effective_time_zone: "America/New_York",
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def pool_definition_row(graph:, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      supplier_resource_id: graph[:resource].id,
      capacity_pair_definition_id: graph[:pair].id,
      capacity_pool_id: graph[:pool].id,
      label: "Inserted pool",
      normalized_label: "inserted pool",
      notes: nil,
      unit_label: "cabins",
      proposed_opening_quantity: 8,
      evidence_kind: "contract",
      evidence_on: Date.new(2026, 5, 1),
      evidence_reference_note: "Contracted capacity",
      evidence_external_reference: nil,
      override: false,
      override_reason: nil,
      position: 9,
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def event_row(graph:, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      supplier_resource_id: graph[:resource].id,
      capacity_pool_id: graph[:pool].id,
      supplying_supplier_id: @provider.id,
      event_type: "established",
      quantity: 8,
      measurement_basis: "resource_units",
      effective_on: Date.new(2026, 6, 1),
      effective_time_zone: "America/New_York",
      applies_at: Time.zone.parse("2026-06-01 12:00:00 UTC"),
      effective_sequence: 1,
      recorded_at: Time.zone.parse("2026-06-01 12:00:00 UTC"),
      evidence_kind: "contract",
      evidence_on: Date.new(2026, 5, 1),
      evidence_reference_note: "Contracted capacity",
      evidence_external_reference: nil,
      override: false,
      override_reason: nil,
      reinstates_event_id: nil,
      corrects_event_id: nil,
      capacity_reconciliation_id: nil,
      actor_id: @actor.id,
      agency_command_idempotency_key_id: nil,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def capacity_event_double(event_type, quantity, sequence)
    Struct.new(:event_type, :quantity, :effective_on, :effective_sequence, :recorded_at, :id).new(
      event_type,
      quantity,
      Date.new(2026, 6, 1),
      sequence,
      Time.zone.parse("2026-06-01 12:00:00 UTC"),
      SecureRandom.uuid_v7
    )
  end
end
