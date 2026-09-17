require "test_helper"

class SupplierArrangementCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    ensure_supplier_sequence!(@agency)
    ensure_supplier_sequence!(@other)
    @contractor = create_supplier("Harbor Contractor").record
    @provider = create_supplier("Harbor Provider").record
    @contact = @contractor.contacts.create!(
      agency: @agency,
      first_name: "Casey",
      last_name: "Contract",
      status: "active"
    )
    @departure = create_complete_draft("M3A Draft")
  end

  test "create arrangement is idempotent and update audits changed fields" do
    created = create_arrangement(idempotency_key: "arr-create-1")
    replay = create_arrangement(idempotency_key: "arr-create-1")

    assert_equal :created, created.status
    assert_equal :replayed, replay.status
    assert_equal created.record.id, replay.record.id
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.created", subject_id: created.record.id).count

    conflict = assert_raises(AgencyCommand::Error) do
      CreateSupplierArrangement.new(
        agency: @agency,
        actor: @admin,
        departure: @departure,
        idempotency_key: "arr-create-1",
        attributes: { name: "Different", contracting_supplier_id: @contractor.id, supplier_contact_id: @contact.id }
      ).call
    end
    assert_equal :conflict, conflict.code

    arrangement = created.record.reload
    update = UpdateSupplierArrangement.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      lock_version: arrangement.lock_version,
      attributes: { name: "Updated Arrangement", supplier_contact_id: "" }
    ).call
    assert_equal :updated, update.status
    assert_nil arrangement.reload.supplier_contact_id
    audit = AuditEvent.where(action: "supplier_arrangement.updated", subject_id: arrangement.id).last
    assert_equal %w[name supplier_contact_id], audit.details["changed_fields"].sort
  end

  test "abandon requires both current locks and replays already abandoned without a second audit" do
    arrangement = create_arrangement.record
    version = arrangement.versions.first

    stale = assert_raises(AgencyCommand::Error) do
      AbandonSupplierArrangement.new(
        agency: @agency,
        actor: @admin,
        arrangement: arrangement,
        reason: "No longer needed",
        arrangement_lock_version: arrangement.lock_version,
        version_lock_version: version.lock_version - 1
      ).call
    end
    assert_equal :conflict, stale.code

    abandoned = AbandonSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement.reload,
      reason: "No longer needed",
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: version.reload.lock_version
    ).call
    assert_equal :updated, abandoned.status
    assert_equal "abandoned", arrangement.reload.status
    assert_equal "abandoned", version.reload.status

    replay = AbandonSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      reason: "",
      arrangement_lock_version: -1,
      version_lock_version: -1
    ).call
    assert_equal :noop, replay.status
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.abandoned", subject_id: arrangement.id).count
  end

  test "item occurrence and resource commands create update reorder and remove draft graph" do
    arrangement = create_arrangement.record
    version = arrangement.versions.first

    first_item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: "item-1",
      attributes: {
        name: "Cabin",
        category: "lodging",
        default_service_provider_id: @provider.id
      }
    ).call.record
    item_created = AuditEvent.where(action: "supplier_arrangement.item_created", subject_id: arrangement.id).last
    assert_equal first_item.id, item_created.details["arrangement_item_id"]
    assert item_created.details["arrangement_item_definition_id"].present?
    assert_equal version.id, item_created.details["supplier_arrangement_version_id"]
    assert_equal @provider.id, item_created.details["default_service_provider_id"]
    assert_equal "lodging", item_created.details["category"]
    assert_equal 1, item_created.details["position"]

    version.reload
    second_item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: "item-2",
      attributes: { name: "Dinner", category: "dining" }
    ).call.record
    first_definition = version.arrangement_item_definitions.find_by!(arrangement_item: first_item)

    UpdateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      definition: first_definition,
      lock_version: first_definition.lock_version,
      attributes: { name: "Suite Cabin", category: "other", other_category_label: "Suite", default_service_provider_id: @provider.id }
    ).call
    assert_equal "Suite Cabin", first_definition.reload.name

    version.reload
    old_positions = version.arrangement_item_definitions.order(:position).each_with_object({}) do |definition, map|
      map[definition.arrangement_item_id] = definition.position
    end
    ReorderArrangementItems.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      arrangement_item_ids: [ second_item.id, first_item.id ]
    ).call
    assert_equal [ second_item.id, first_item.id ], version.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)
    reorder_audit = AuditEvent.where(action: "supplier_arrangement.items_reordered", subject_id: arrangement.id).last
    assert_equal [ second_item.id, first_item.id ], reorder_audit.details["arrangement_item_ids"]
    assert_equal old_positions.stringify_keys.transform_values(&:to_i), reorder_audit.details["old_positions"].transform_values(&:to_i)
    assert_equal({ second_item.id => 1, first_item.id => 2 }.stringify_keys, reorder_audit.details["new_positions"].transform_values(&:to_i))

    occurrence = CreateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      item: first_item,
      version_lock_version: version.reload.lock_version,
      idempotency_key: "occ-1",
      attributes: { name: "Check in", starts_on: "2026-10-01", ends_on: "2026-10-02" }
    ).call.record
    occurrence_definition = version.service_occurrence_definitions.find_by!(service_occurrence: occurrence)
    assert_equal "planned", occurrence.status
    assert_equal @departure.time_zone, occurrence_definition.time_zone
    occurrence_created = AuditEvent.where(action: "supplier_arrangement.occurrence_created", subject_id: arrangement.id).last
    assert_equal occurrence.id, occurrence_created.details["service_occurrence_id"]
    assert occurrence_created.details["service_occurrence_definition_id"].present?
    assert_equal "2026-10-01", occurrence_created.details["starts_on"]
    assert_equal version.id, occurrence_created.details["supplier_arrangement_version_id"]

    UpdateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      definition: occurrence_definition,
      lock_version: occurrence_definition.lock_version,
      attributes: { name: "Late check in", starts_on: "2026-10-01", ends_on: "2026-10-02", time_zone: "America/Chicago" }
    ).call
    assert_equal "America/Chicago", occurrence_definition.reload.time_zone

    first_resource = CreateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      item: first_item,
      version_lock_version: version.reload.lock_version,
      idempotency_key: "res-1",
      attributes: { name: "Room block" }
    ).call.record
    resource_created = AuditEvent.where(action: "supplier_arrangement.resource_created", subject_id: arrangement.id).last
    assert_equal first_resource.id, resource_created.details["supplier_resource_id"]
    assert resource_created.details["supplier_resource_definition_id"].present?
    assert_equal 1, resource_created.details["position"]

    second_resource = CreateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      item: first_item,
      version_lock_version: version.reload.lock_version,
      idempotency_key: "res-2",
      attributes: { name: "Guide room" }
    ).call.record
    resource_definition = version.supplier_resource_definitions.find_by!(supplier_resource: first_resource)
    UpdateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      definition: resource_definition,
      lock_version: resource_definition.lock_version,
      attributes: { name: "Updated room block" }
    ).call
    ReorderSupplierResources.new(
      agency: @agency,
      actor: @admin,
      item: first_item,
      version_lock_version: version.reload.lock_version,
      supplier_resource_ids: [ second_resource.id, first_resource.id ]
    ).call
    assert_equal [ second_resource.id, first_resource.id ], version.supplier_resource_definitions.where(arrangement_item: first_item).order(:position).pluck(:supplier_resource_id)
    resource_reorder = AuditEvent.where(action: "supplier_arrangement.resources_reordered", subject_id: arrangement.id).last
    assert_equal [ second_resource.id, first_resource.id ], resource_reorder.details["supplier_resource_ids"]
    assert resource_reorder.details["old_positions"].present?
    assert resource_reorder.details["new_positions"].present?

    occurrence_definition_id = occurrence_definition.id
    RemoveServiceOccurrence.new(agency: @agency, actor: @admin, occurrence: occurrence, version_lock_version: version.reload.lock_version).call
    assert_not ServiceOccurrence.exists?(occurrence.id)
    occurrence_removed = AuditEvent.where(action: "supplier_arrangement.occurrence_removed", subject_id: arrangement.id).last
    assert_equal [ occurrence_definition_id ], occurrence_removed.details["service_occurrence_definition_ids"]

    first_resource_definition_id = version.supplier_resource_definitions.find_by!(supplier_resource: first_resource).id
    RemoveSupplierResource.new(agency: @agency, actor: @admin, resource: first_resource, version_lock_version: version.reload.lock_version).call
    assert_not SupplierResource.exists?(first_resource.id)
    resource_removed = AuditEvent.where(action: "supplier_arrangement.resource_removed", subject_id: arrangement.id).last
    assert_equal [ first_resource_definition_id ], resource_removed.details["supplier_resource_definition_ids"]

    remaining_resource_id = second_resource.id
    remaining_resource_definition_id = version.supplier_resource_definitions.find_by!(supplier_resource: second_resource).id
    item_definition_id = version.arrangement_item_definitions.find_by!(arrangement_item: first_item).id
    RemoveArrangementItem.new(agency: @agency, actor: @admin, item: first_item, version_lock_version: version.reload.lock_version).call
    assert_not ArrangementItem.exists?(first_item.id)
    item_removed = AuditEvent.where(action: "supplier_arrangement.item_removed", subject_id: arrangement.id).last
    assert_equal [ item_definition_id ], item_removed.details["arrangement_item_definition_ids"]
    assert_equal [ remaining_resource_id ], item_removed.details["supplier_resource_ids"]
    assert_equal [ remaining_resource_definition_id ], item_removed.details["supplier_resource_definition_ids"]
  end

  test "child creates replay with the original submitted version lock" do
    arrangement = create_arrangement.record
    version = arrangement.versions.first
    submitted_lock = version.lock_version

    item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: submitted_lock,
      idempotency_key: "item-replay",
      attributes: { name: "Cabin", category: "lodging" }
    ).call.record
    assert version.reload.lock_version > submitted_lock

    item_replay = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: submitted_lock,
      idempotency_key: "item-replay",
      attributes: { name: "Cabin", category: "lodging" }
    ).call
    assert_equal :replayed, item_replay.status
    assert_equal item.id, item_replay.record.id
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.item_created", subject_id: arrangement.id).count

    occurrence_lock = version.reload.lock_version
    occurrence = CreateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: occurrence_lock,
      idempotency_key: "occ-replay",
      attributes: { name: "Stay", starts_on: "2026-10-01", ends_on: "2026-10-02" }
    ).call.record
    occurrence_replay = CreateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: occurrence_lock,
      idempotency_key: "occ-replay",
      attributes: { name: "Stay", starts_on: "2026-10-01", ends_on: "2026-10-02" }
    ).call
    assert_equal :replayed, occurrence_replay.status
    assert_equal occurrence.id, occurrence_replay.record.id

    resource_lock = version.reload.lock_version
    resource = CreateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: resource_lock,
      idempotency_key: "res-replay",
      attributes: { name: "Room block" }
    ).call.record
    resource_replay = CreateSupplierResource.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: resource_lock,
      idempotency_key: "res-replay",
      attributes: { name: "Room block" }
    ).call
    assert_equal :replayed, resource_replay.status
    assert_equal resource.id, resource_replay.record.id
  end

  test "forced inactive contractor and departed recovery reject expansion and allow cleanup" do
    arrangement = create_arrangement.record
    version = arrangement.versions.first
    item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: "recovery-item",
      attributes: { name: "Cabin", category: "lodging", default_service_provider_id: @provider.id }
    ).call.record
    CreateServiceOccurrence.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: version.reload.lock_version,
      idempotency_key: "recovery-occ",
      attributes: { name: "Stay", starts_on: "2026-10-01", ends_on: "2026-10-02" }
    ).call

    ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: @contractor.reload,
      status: "inactive",
      lock_version: @contractor.lock_version,
      force: true,
      force_reason: "Contractor ceased operations"
    ).call

    rename = assert_raises(AgencyCommand::Error) do
      UpdateSupplierArrangement.new(
        agency: @agency,
        actor: @admin,
        arrangement: arrangement.reload,
        lock_version: arrangement.lock_version,
        attributes: { name: "Renamed after force", supplier_contact_id: "" }
      ).call
    end
    assert_equal :invalid_state, rename.code

    create_item = assert_raises(AgencyCommand::Error) do
      CreateArrangementItem.new(
        agency: @agency,
        actor: @admin,
        arrangement: arrangement,
        version_lock_version: version.reload.lock_version,
        idempotency_key: "blocked-item",
        attributes: { name: "Extra", category: "dining" }
      ).call
    end
    assert_equal :invalid_state, create_item.code

    inherit_occ = assert_raises(AgencyCommand::Error) do
      CreateServiceOccurrence.new(
        agency: @agency,
        actor: @admin,
        item: item,
        version_lock_version: version.reload.lock_version,
        idempotency_key: "blocked-occ",
        attributes: { name: "Inherited", starts_on: "2026-10-03", ends_on: "2026-10-03" }
      ).call
    end
    assert_equal :invalid_state, inherit_occ.code

    clear_contact = UpdateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement.reload,
      lock_version: arrangement.lock_version,
      attributes: { name: arrangement.name, supplier_contact_id: "" }
    ).call
    assert_equal :updated, clear_contact.status
    assert_nil arrangement.reload.supplier_contact_id

    RemoveArrangementItem.new(
      agency: @agency,
      actor: @admin,
      item: item,
      version_lock_version: version.reload.lock_version
    ).call
    assert_not ArrangementItem.exists?(item.id)

    active_contractor = create_supplier("Active Departed Contractor").record
    departed_arrangement = CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: "departed-plan",
      attributes: { name: "Departed Plan", contracting_supplier_id: active_contractor.id }
    ).call.record
    departed_version = departed_arrangement.versions.first
    departed_item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: departed_arrangement,
      version_lock_version: departed_version.lock_version,
      idempotency_key: "departed-item",
      attributes: { name: "Transfer", category: "ground_transportation", default_service_provider_id: @provider.id }
    ).call.record
    departed_definition = departed_version.arrangement_item_definitions.find_by!(arrangement_item: departed_item)
    ActivateDeparture.new(agency: @agency, actor: @admin, departure: @departure.reload, lock_version: @departure.lock_version).call
    Departure.where(id: @departure.id).update_all(status: "departed", departed_at: Time.current, updated_at: Time.current)

    expand = assert_raises(AgencyCommand::Error) do
      CreateArrangementItem.new(
        agency: @agency,
        actor: @admin,
        arrangement: departed_arrangement,
        version_lock_version: departed_version.reload.lock_version,
        idempotency_key: "departed-expand",
        attributes: { name: "Extra", category: "dining" }
      ).call
    end
    assert_equal :invalid_state, expand.code

    ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: @provider.reload,
      status: "inactive",
      lock_version: @provider.lock_version,
      force: true,
      force_reason: "Provider closed"
    ).call

    clear_provider = UpdateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      definition: departed_definition.reload,
      lock_version: departed_definition.lock_version,
      attributes: {
        name: departed_definition.name,
        category: departed_definition.category,
        other_category_label: departed_definition.other_category_label,
        description: departed_definition.description,
        default_service_provider_id: ""
      }
    ).call
    assert_equal :updated, clear_provider.status
    assert_nil departed_definition.reload.default_service_provider_id
  end

  test "occurrences sort date-only before timed then by local time and name" do
    arrangement = create_arrangement.record
    item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: arrangement.versions.first.lock_version,
      idempotency_key: "order-item",
      attributes: { name: "Day", category: "activity_attraction" }
    ).call.record
    version = arrangement.versions.first.reload

    late = CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item, version_lock_version: version.lock_version, idempotency_key: "late",
      attributes: { name: "Zebra", starts_on: "2026-10-01", ends_on: "2026-10-01", starts_at_local: "15:00", ends_at_local: "16:00" }
    ).call.record
    version.reload
    early = CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item, version_lock_version: version.lock_version, idempotency_key: "early",
      attributes: { name: "Alpha", starts_on: "2026-10-01", ends_on: "2026-10-01", starts_at_local: "09:00", ends_at_local: "10:00" }
    ).call.record
    version.reload
    date_only = CreateServiceOccurrence.new(
      agency: @agency, actor: @admin, item: item, version_lock_version: version.lock_version, idempotency_key: "date-only",
      attributes: { name: "Morning note", starts_on: "2026-10-01", ends_on: "2026-10-01" }
    ).call.record

    ordered_ids = version.service_occurrence_definitions
      .where(arrangement_item: item)
      .order(Arel.sql("starts_on ASC, CASE WHEN starts_at_local IS NULL THEN 0 ELSE 1 END ASC, starts_at_local ASC NULLS FIRST, lower(name) ASC, id ASC"))
      .pluck(:service_occurrence_id)
    assert_equal [ date_only.id, early.id, late.id ], ordered_ids
  end

  test "departed departure cannot create arrangement and invalid occurrence zone is rejected" do
    departed = activate_departure!(create_complete_draft("Departed"))
    Departure.where(id: departed.id).update_all(status: "departed", departed_at: Time.current, updated_at: Time.current)

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierArrangement.new(
        agency: @agency,
        actor: @admin,
        departure: departed.reload,
        idempotency_key: "departed-arr",
        attributes: { name: "Too Late", contracting_supplier_id: @contractor.id }
      ).call
    end
    assert_equal :invalid_state, error.code

    arrangement = create_arrangement.record
    item = CreateArrangementItem.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: arrangement.versions.first.lock_version,
      idempotency_key: "zone-item",
      attributes: { name: "Transfer", category: "ground_transportation" }
    ).call.record
    version = arrangement.versions.first.reload
    zone = assert_raises(AgencyCommand::Error) do
      CreateServiceOccurrence.new(
        agency: @agency,
        actor: @admin,
        item: item,
        version_lock_version: version.lock_version,
        idempotency_key: "bad-zone",
        attributes: { name: "Pickup", starts_on: "2026-10-01", ends_on: "2026-10-01", time_zone: "Not/AZone" }
      ).call
    end
    assert_equal :invalid, zone.code
  end

  test "list filters truncates and viewers can read" do
    51.times do |index|
      create_arrangement(name: format("Alpha %03d", index), idempotency_key: "list-#{index}")
    end
    create_arrangement(name: "Beta", idempotency_key: "list-beta")

    outcome = ListDepartureArrangements.call(agency: @agency, actor: @viewer, departure: @departure, q: "Alpha")
    assert_equal 50, outcome.records.size
    assert outcome.truncated
    assert outcome.records.all? { |arrangement| arrangement.name.start_with?("Alpha") }

    by_supplier = ListDepartureArrangements.call(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      contracting_supplier_id: @contractor.id
    )
    assert by_supplier.records.all? { |arrangement| arrangement.contracting_supplier_id == @contractor.id }
  end

  test "return to draft is not blocked by unactivated arrangement drafts" do
    departure = activate_departure!(create_complete_draft("Active With Draft Arrangement"))
    CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: departure,
      idempotency_key: "active-arr",
      attributes: { name: "Tentative Hotel", contracting_supplier_id: @contractor.id }
    ).call

    result = ReturnDepartureToDraft.new(
      agency: @agency,
      actor: @admin,
      departure: departure.reload,
      reason: "Supplier plan still tentative",
      lock_version: departure.lock_version
    ).call
    assert_equal :updated, result.status
    assert_equal "draft", departure.reload.status
  end

  test "guided item setup is atomic and replays its exact child result association" do
    arrangement = create_arrangement.record
    version = arrangement.versions.first
    arguments = {
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      idempotency_key: "guided-item-setup-1",
      item_attributes: {
        name: "Harbor stay",
        category: "lodging",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: "First stay",
        starts_on: "2026-10-01",
        ends_on: "2026-10-03"
      },
      resource_attributes: { name: "Standard room" }
    }

    created = CreateArrangementItemSetup.new(**arguments).call
    replay = CreateArrangementItemSetup.new(**arguments.merge(version_lock_version: -1)).call

    assert_equal :created, created.status
    assert_equal :replayed, replay.status
    assert_instance_of ArrangementItem, created.record.item
    assert_instance_of ServiceOccurrence, created.record.occurrence
    assert_instance_of SupplierResource, created.record.resource
    assert_equal created.record.item, replay.record.item
    assert_equal created.record.occurrence, replay.record.occurrence
    assert_equal created.record.resource, replay.record.resource
    association = AgencyCommandIdempotencyKey.find_by!(
      agency: @agency, command_name: "CreateArrangementItemSetup",
      idempotency_key: "guided-item-setup-1"
    ).arrangement_item_setup_result
    assert_equal created.record.item.id, association.arrangement_item_id
    assert_equal created.record.occurrence.id, association.service_occurrence_id
    assert_equal created.record.resource.id, association.supplier_resource_id
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.item_setup_created", subject_id: arrangement.id
    ).count
    assert_equal 0, AuditEvent.where(
      action: %w[
        supplier_arrangement.item_created
        supplier_arrangement.occurrence_created
        supplier_arrangement.resource_created
      ],
      subject_id: arrangement.id
    ).count

    assert_raises(AgencyCommand::Error) do
      CreateArrangementItemSetup.new(
        **arguments.merge(item_attributes: { name: "Changed", category: "lodging" })
      ).call
    end

    counts = [
      ArrangementItem.count, ServiceOccurrence.count, SupplierResource.count, AuditEvent.count
    ]
    error = assert_raises(AgencyCommand::Error) do
      CreateArrangementItemSetup.new(
        **arguments.merge(
          idempotency_key: "guided-item-setup-invalid",
          version_lock_version: version.reload.lock_version,
          occurrence_attributes: {
            name: "Invalid stay", starts_on: "2026-10-03", ends_on: "2026-10-01"
          }
        )
      ).call
    end
    assert_equal :invalid, error.code
    assert_equal counts, [
      ArrangementItem.count, ServiceOccurrence.count, SupplierResource.count, AuditEvent.count
    ]
  end

  test "guided item setup rejects stale cross-Agency inactive and departed expansion" do
    arrangement = create_arrangement.record
    version = arrangement.versions.first
    base = {
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      version_lock_version: version.lock_version - 1,
      idempotency_key: "guided-item-stale",
      item_attributes: { name: "Stale cabin", category: "lodging" }
    }
    stale = assert_raises(AgencyCommand::Error) { CreateArrangementItemSetup.new(**base).call }
    assert_equal :conflict, stale.code
    assert_empty arrangement.arrangement_items

    other_supplier = @other.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-#{SecureRandom.random_number(900_000) + 100_000}",
      display_name: "Other setup Supplier"
    )
    other_departure = @other.departures.create!(
      name: "Other setup departure",
      responsible_office: @other.offices.first,
      responsible_agency_user: @other.agency_users.active.first
    )
    other_arrangement = @other.supplier_arrangements.create!(
      departure: other_departure,
      contracting_supplier: other_supplier,
      name: "Other setup arrangement"
    )
    other_version = other_arrangement.versions.create!(
      agency: @other,
      departure: other_departure,
      version_number: 1
    )
    assert_raises(ActiveRecord::RecordNotFound) do
      CreateArrangementItemSetup.new(
        agency: @agency,
        actor: @staff,
        arrangement: other_arrangement,
        version_lock_version: other_version.lock_version,
        idempotency_key: "guided-item-cross-agency",
        item_attributes: { name: "Forbidden", category: "lodging" }
      ).call
    end

    ChangeSupplierStatus.new(
      agency: @agency,
      actor: @admin,
      supplier: @contractor,
      status: "inactive",
      lock_version: @contractor.lock_version,
      force: true,
      force_reason: "Supplier closed"
    ).call
    inactive = assert_raises(AgencyCommand::Error) do
      CreateArrangementItemSetup.new(
        **base.merge(
          version_lock_version: version.reload.lock_version,
          idempotency_key: "guided-item-inactive"
        )
      ).call
    end
    assert_equal :invalid_state, inactive.code

    active_supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-#{SecureRandom.random_number(900_000) + 100_000}",
      display_name: "Departed setup Supplier"
    )
    departed_arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: active_supplier,
      name: "Departed setup arrangement"
    )
    departed_version = departed_arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
    ActivateDeparture.new(
      agency: @agency,
      actor: @admin,
      departure: @departure.reload,
      lock_version: @departure.lock_version
    ).call
    Departure.where(id: @departure.id).update_all(
      status: "departed", departed_at: Time.current, updated_at: Time.current
    )
    departed = assert_raises(AgencyCommand::Error) do
      CreateArrangementItemSetup.new(
        agency: @agency,
        actor: @staff,
        arrangement: departed_arrangement,
        version_lock_version: departed_version.lock_version,
        idempotency_key: "guided-item-departed",
        item_attributes: { name: "Too late", category: "lodging" }
      ).call
    end
    assert_equal :invalid_state, departed.code
  end

  private

  def create_arrangement(name: "Hotel Block", idempotency_key: SecureRandom.hex(6))
    CreateSupplierArrangement.new(
      agency: @agency,
      actor: @admin,
      departure: @departure,
      idempotency_key: idempotency_key,
      attributes: { name: name, contracting_supplier_id: @contractor.id, supplier_contact_id: @contact.id }
    ).call
  end

  def create_supplier(display_name)
    CreateSupplier.new(
      agency: @agency,
      actor: @admin,
      kind: "organization",
      names: { display_name: display_name },
      categories: [ "lodging" ]
    ).call
  end

  def create_complete_draft(name)
    CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name: name,
        starts_on: Date.new(2026, 10, 1),
        ends_on: Date.new(2026, 10, 8),
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      },
      current_office: @office
    ).call.record
  end

  def activate_departure!(departure)
    ActivateDeparture.new(agency: @agency, actor: @admin, departure: departure, lock_version: departure.lock_version).call.record
  end

  def ensure_supplier_sequence!(agency)
    agency.reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end
end
