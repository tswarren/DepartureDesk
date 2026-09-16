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
    ReorderArrangementItems.new(
      agency: @agency,
      actor: @admin,
      arrangement: arrangement,
      version_lock_version: version.lock_version,
      arrangement_item_ids: [ second_item.id, first_item.id ]
    ).call
    assert_equal [ second_item.id, first_item.id ], version.arrangement_item_definitions.order(:position).pluck(:arrangement_item_id)

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

    RemoveServiceOccurrence.new(agency: @agency, actor: @admin, occurrence: occurrence, version_lock_version: version.reload.lock_version).call
    assert_not ServiceOccurrence.exists?(occurrence.id)
    RemoveSupplierResource.new(agency: @agency, actor: @admin, resource: first_resource, version_lock_version: version.reload.lock_version).call
    assert_not SupplierResource.exists?(first_resource.id)
    RemoveArrangementItem.new(agency: @agency, actor: @admin, item: first_item, version_lock_version: version.reload.lock_version).call
    assert_not ArrangementItem.exists?(first_item.id)
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
