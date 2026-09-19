require "test_helper"

class SupplierArrangementConstraintsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other_agency = agencies(:cove)
    @departure = @agency.departures.create!(name: "Harbor M3A Departure")
    @other_departure = @other_agency.departures.create!(name: "Cove M3A Departure")
    @contractor = create_supplier(@agency, "SUP-310001", "Harbor Contractor")
    @other_supplier = create_supplier(@other_agency, "SUP-320001", "Cove Contractor")
    @same_agency_supplier = create_supplier(@agency, "SUP-310002", "Harbor Provider")
    @contact = @contractor.contacts.create!(
      agency: @agency,
      first_name: "Contract",
      last_name: "Contact",
      status: "active"
    )
    @other_contact = @same_agency_supplier.contacts.create!(
      agency: @agency,
      first_name: "Wrong",
      last_name: "Contractor",
      status: "active"
    )
  end

  test "M3A tables have direct ownership columns UUIDv7 defaults and expected lock columns" do
    connection = ActiveRecord::Base.connection
    tables = %w[
      supplier_arrangements
      supplier_arrangement_versions
      arrangement_items
      service_occurrences
      supplier_resources
      arrangement_item_definitions
      service_occurrence_definitions
      supplier_resource_definitions
    ]

    tables.each do |table|
      columns = connection.columns(table).index_by(&:name)
      assert_equal "uuidv7()", columns.fetch("id").default_function
      assert_equal "uuid", columns.fetch("agency_id").sql_type
      assert_equal "uuid", columns.fetch("departure_id").sql_type
      assert_includes columns.fetch("created_at").sql_type, "with time zone"
      assert_includes columns.fetch("updated_at").sql_type, "with time zone"
    end

    assert_not_includes connection.columns("arrangement_items").map(&:name), "lock_version"
    assert_not_includes connection.columns("supplier_resources").map(&:name), "lock_version"
    assert_includes connection.columns("service_occurrences").map(&:name), "lock_version"
    assert_not_includes connection.columns("service_occurrences").map(&:name), "cancelled_at"
    assert_not_includes connection.columns("service_occurrence_definitions").map(&:name), "status"
  end

  test "same-agency departure contractor and contact pairings are enforced" do
    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierArrangement.transaction(requires_new: true) do
        SupplierArrangement.insert!(arrangement_row(departure_id: @other_departure.id))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierArrangement.transaction(requires_new: true) do
        SupplierArrangement.insert!(arrangement_row(contracting_supplier_id: @other_supplier.id))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierArrangement.transaction(requires_new: true) do
        SupplierArrangement.insert!(arrangement_row(supplier_contact_id: @other_contact.id))
      end
    end

    arrangement = create_arrangement
    assert_equal @contact.id, arrangement.supplier_contact_id
  end

  test "version lifecycle partial uniqueness and abandonment constraints are enforced" do
    arrangement = create_arrangement
    create_version(arrangement)

    assert_raises(ActiveRecord::RecordNotUnique) do
      SupplierArrangementVersion.create!(
        agency: @agency,
        departure: @departure,
        supplier_arrangement: arrangement,
        version_number: 2,
        status: "draft"
      )
    end

    SupplierArrangementVersion.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      version_number: 2,
      status: "activated",
      activated_at: Time.current
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      SupplierArrangementVersion.create!(
        agency: @agency,
        departure: @departure,
        supplier_arrangement: arrangement,
        version_number: 3,
        status: "activated",
        activated_at: Time.current
      )
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangementVersion.transaction(requires_new: true) do
        SupplierArrangementVersion.insert!(version_row(arrangement, version_number: 0))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierArrangementVersion.transaction(requires_new: true) do
        SupplierArrangementVersion.insert!(version_row(
          arrangement,
          version_number: 4,
          status: "abandoned",
          abandoned_at: Time.current,
          abandoned_reason: nil
        ))
      end
    end
  end

  test "child and definition composite foreign keys reject cross-arrangement attachment" do
    first = create_graph(prefix: "First")
    second = create_graph(prefix: "Second")

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ArrangementItemDefinition.transaction(requires_new: true) do
        ArrangementItemDefinition.insert!(item_definition_row(
          supplier_arrangement_version_id: first[:version].id,
          supplier_arrangement_id: second[:arrangement].id,
          arrangement_item_id: second[:item].id,
          position: 3
        ))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      ServiceOccurrenceDefinition.transaction(requires_new: true) do
        ServiceOccurrenceDefinition.insert!(occurrence_definition_row(
          supplier_arrangement_version_id: first[:version].id,
          supplier_arrangement_id: second[:arrangement].id,
          arrangement_item_id: second[:item].id,
          service_occurrence_id: second[:occurrence].id
        ))
      end
    end

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierResourceDefinition.transaction(requires_new: true) do
        SupplierResourceDefinition.insert!(resource_definition_row(
          supplier_arrangement_version_id: first[:version].id,
          supplier_arrangement_id: second[:arrangement].id,
          arrangement_item_id: second[:item].id,
          supplier_resource_id: second[:resource].id,
          position: 3
        ))
      end
    end
  end

  test "category occurrence status schedule and timezone constraints are enforced" do
    graph = create_graph

    assert_raises(ActiveRecord::StatementInvalid) do
      ArrangementItemDefinition.transaction(requires_new: true) do
        ArrangementItemDefinition.insert!(item_definition_row(category: "other", other_category_label: nil, position: 2))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOccurrence.transaction(requires_new: true) do
        ServiceOccurrence.insert!(occurrence_row(graph[:item], status: "completed"))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOccurrenceDefinition.transaction(requires_new: true) do
        ServiceOccurrenceDefinition.insert!(occurrence_definition_row(
          starts_on: Date.new(2026, 6, 3),
          ends_on: Date.new(2026, 6, 2)
        ))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOccurrenceDefinition.transaction(requires_new: true) do
        ServiceOccurrenceDefinition.insert!(occurrence_definition_row(starts_at_local: "09:00:00", ends_at_local: nil))
      end
    end

    assert_raises(ActiveRecord::StatementInvalid) do
      ServiceOccurrenceDefinition.transaction(requires_new: true) do
        ServiceOccurrenceDefinition.insert!(occurrence_definition_row(time_zone: "Not/AZone"))
      end
    end
  end

  test "item and resource position constraints are deferrable for swaps" do
    graph = create_graph
    second_item = graph[:arrangement].arrangement_items.create!(agency: @agency, departure: @departure)
    second_definition = graph[:version].arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: second_item,
      name: "Second item",
      category: "lodging",
      position: 2
    )

    ArrangementItemDefinition.transaction(requires_new: true) do
      graph[:item_definition].update!(position: 2)
      second_definition.update!(position: 1)
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS arrangement_item_definitions_position_unique IMMEDIATE")
    end

    assert_equal 2, graph[:item_definition].reload.position
    assert_equal 1, second_definition.reload.position

    assert_raises(ActiveRecord::StatementInvalid) do
      ArrangementItemDefinition.transaction(requires_new: true) do
        graph[:item_definition].update!(position: 1)
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS arrangement_item_definitions_position_unique IMMEDIATE")
      end
    end

    second_resource = graph[:item].supplier_resources.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement]
    )
    second_resource_definition = graph[:version].supplier_resource_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: graph[:item],
      supplier_resource: second_resource,
      name: "Second resource",
      position: 2
    )

    SupplierResourceDefinition.transaction(requires_new: true) do
      graph[:resource_definition].update!(position: 2)
      second_resource_definition.update!(position: 1)
      ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_resource_definitions_position_unique IMMEDIATE")
    end

    assert_equal 2, graph[:resource_definition].reload.position
    assert_equal 1, second_resource_definition.reload.position

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierResourceDefinition.transaction(requires_new: true) do
        graph[:resource_definition].update!(position: 1)
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_resource_definitions_position_unique IMMEDIATE")
      end
    end
  end

  test "duplicate sibling names are accepted" do
    graph = create_graph
    sibling = graph[:arrangement].arrangement_items.create!(agency: @agency, departure: @departure)

    duplicate = graph[:version].arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: graph[:arrangement],
      arrangement_item: sibling,
      name: graph[:item_definition].name,
      category: "cruise",
      position: 2
    )

    assert_equal graph[:item_definition].name, duplicate.name
  end

  test "immutable ownership triggers reject direct SQL owner changes" do
    graph = create_graph
    other_item = graph[:arrangement].arrangement_items.create!(agency: @agency, departure: @departure)

    updates = [
      [ SupplierArrangement, graph[:arrangement].id, { departure_id: @other_departure.id } ],
      [ SupplierArrangementVersion, graph[:version].id, { version_number: 2 } ],
      [ ArrangementItem, graph[:item].id, { supplier_arrangement_id: create_arrangement(name: "Other Arrangement").id } ],
      [ ServiceOccurrence, graph[:occurrence].id, { arrangement_item_id: other_item.id } ],
      [ SupplierResource, graph[:resource].id, { arrangement_item_id: other_item.id } ],
      [ ArrangementItemDefinition, graph[:item_definition].id, { arrangement_item_id: other_item.id } ],
      [ ServiceOccurrenceDefinition, graph[:occurrence_definition].id, { arrangement_item_id: other_item.id } ],
      [ SupplierResourceDefinition, graph[:resource_definition].id, { arrangement_item_id: other_item.id } ]
    ]

    updates.each do |klass, id, attrs|
      assert_raises(ActiveRecord::StatementInvalid, klass.name) do
        klass.transaction(requires_new: true) do
          klass.where(id: id).update_all(attrs)
        end
      end
    end
  end

  test "idempotency keys are unique by agency command and key and retain payload digest" do
    arrangement = create_arrangement
    first = AgencyCommandIdempotencyKey.create!(
      agency: @agency,
      command_name: "CreateSupplierArrangement",
      idempotency_key: "same-key",
      payload_digest: "sha256:first",
      result_record_type: "SupplierArrangement",
      result_record_id: arrangement.id
    )

    assert_equal "sha256:first", first.payload_digest
    assert_raises(ActiveRecord::RecordNotUnique) do
      AgencyCommandIdempotencyKey.create!(
        agency: @agency,
        command_name: "CreateSupplierArrangement",
        idempotency_key: "same-key",
        payload_digest: "sha256:second",
        result_record_type: "SupplierArrangement",
        result_record_id: arrangement.id
      )
    end

    AgencyCommandIdempotencyKey.create!(
      agency: @other_agency,
      command_name: "CreateSupplierArrangement",
      idempotency_key: "same-key",
      payload_digest: "sha256:first",
      result_record_type: "SupplierArrangement",
      result_record_id: arrangement.id
    )
  end

  test "catalogs include M3A permissions audit actions and subject ownership" do
    assert_equal %w[administrator], AccessPermission::CATALOG.fetch(:force_inactivate_supplier_with_dependencies)
    assert_equal SupplierArrangement::STATUSES, %w[draft active ended abandoned]
    assert_equal SupplierArrangementVersion::STATUSES, %w[draft activated superseded abandoned]
    assert_equal ServiceOccurrence::STATUSES, %w[planned cancelled]
    assert_not_includes SupplierArrangement::STATUSES, "cancelled"
    assert_equal ArrangementItemDefinition::CATEGORIES, checked_item_categories

    AuditEvent::ACTIONS.grep(/\Asupplier_arrangement\./).then do |actions|
      assert_equal 60, actions.size
      assert_includes actions, "supplier_arrangement.activated"
      assert_includes actions, "supplier_arrangement.successor_created"
      assert_includes actions, "supplier_arrangement.successor_activated"
      assert_includes actions, "supplier_arrangement.identifier_superseded"
      assert_includes actions, "supplier_arrangement.commitments_disposed"
      assert_includes actions, "supplier_arrangement.commitment_reopened"
      assert_includes actions, "supplier_arrangement.item_setup_created"
      assert_includes actions, "supplier_arrangement.capacity_pairs_bulk_classified"
      assert_includes actions, "supplier_arrangement.capacity_pair_pool_configured"
      assert_includes actions, "supplier_arrangement.cost_setup_created"
      assert_includes actions, "supplier_arrangement.capacity_reconciliation_resolved"
      assert_includes actions, "supplier_arrangement.cost_occupancy_profiles_reordered"
      assert_includes actions, "supplier_arrangement.commitment_trigger_created"
      assert_includes actions, "supplier_arrangement.commitment_trigger_updated"
      assert_includes actions, "supplier_arrangement.commitment_trigger_removed"
    end
    assert_includes AuditEvent::SUBJECT_TYPES, "SupplierArrangement"

    actor = agency_users(:harbor_admin)
    audit = RecordAdministrativeAudit.record(
      agency: @agency,
      action: "supplier_arrangement.created",
      subject: create_arrangement(name: "Audited Arrangement"),
      actor_agency_user: actor,
      details: {}
    )
    assert_equal "SupplierArrangement", audit.subject_type
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

  def create_arrangement(name: "Test Arrangement")
    SupplierArrangement.create!(
      agency: @agency,
      departure: @departure,
      contracting_supplier: @contractor,
      supplier_contact: @contact,
      name: name,
      status: "draft"
    )
  end

  def create_version(arrangement)
    arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1,
      status: "draft"
    )
  end

  def create_graph(prefix: "Graph")
    arrangement = create_arrangement(name: "#{prefix} Arrangement")
    version = create_version(arrangement)
    item = arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    item_definition = version.arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      name: "#{prefix} item",
      category: "cruise",
      default_service_provider: @same_agency_supplier,
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
      service_provider: @same_agency_supplier
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

  def arrangement_row(**attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      contracting_supplier_id: @contractor.id,
      supplier_contact_id: @contact.id,
      name: "Inserted Arrangement",
      status: "draft",
      abandoned_at: nil,
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def version_row(arrangement, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: arrangement.id,
      version_number: 1,
      status: "draft",
      abandoned_at: nil,
      abandoned_reason: nil,
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def item_definition_row(**attrs)
    graph = attrs.delete(:graph) || create_graph(prefix: "Inserted Item")
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      name: "Inserted item",
      description: nil,
      category: "cruise",
      other_category_label: nil,
      default_service_provider_id: nil,
      position: 99,
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def occurrence_row(item, **attrs)
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: item.supplier_arrangement_id,
      arrangement_item_id: item.id,
      status: "planned",
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def occurrence_definition_row(**attrs)
    graph = attrs.delete(:graph) || create_graph(prefix: "Inserted Occurrence")
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      service_occurrence_id: graph[:occurrence].id,
      name: "Inserted occurrence",
      description: nil,
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 1),
      starts_at_local: nil,
      ends_at_local: nil,
      time_zone: "America/New_York",
      service_provider_id: nil,
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def resource_definition_row(**attrs)
    graph = attrs.delete(:graph) || create_graph(prefix: "Inserted Resource")
    {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      supplier_resource_id: graph[:resource].id,
      name: "Inserted resource",
      description: nil,
      position: 99,
      lock_version: 0,
      created_at: Time.current,
      updated_at: Time.current
    }.merge(attrs)
  end

  def checked_item_categories
    definition = ActiveRecord::Base.connection.select_value(<<~SQL)
      SELECT pg_get_constraintdef(c.oid)
      FROM pg_constraint c
      JOIN pg_class t ON t.oid = c.conrelid
      WHERE t.relname = 'arrangement_item_definitions'
        AND c.conname = 'arrangement_item_definitions_category'
    SQL
    definition.scan(/'([^']+)'::character varying/).flatten
  end
end
