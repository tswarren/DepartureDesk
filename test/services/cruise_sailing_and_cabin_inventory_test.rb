# frozen_string_literal: true

require "test_helper"

class CruiseSailingAndCabinInventoryTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @admin = agency_users(:harbor_admin)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency,
      first_name: "Group",
      last_name: "Desk",
      status: "active"
    )
  end

  test "cruise sailing create is atomic idempotent and replays the same section" do
    arguments = sailing_arguments(idempotency_key: "cruise-sailing-1")

    created = CreateCruiseSailingSetup.new(**arguments).call
    assert_equal :created, created.status
    arrangement = created.record.arrangement
    item = created.record.item
    occurrence = created.record.occurrence
    version = arrangement.versions.sole

    assert_equal "draft", arrangement.status
    assert_equal "cruise", version.arrangement_item_definitions.sole.category
    assert_equal "Celebrity Beyond", version.arrangement_item_definitions.sole.name
    assert_equal "managed", version.arrangement_item_definitions.sole.capacity_management
    assert_equal "Western Caribbean", version.service_occurrence_definitions.sole.name
    assert_equal Date.new(2027, 11, 6), version.service_occurrence_definitions.sole.starts_on
    assert_equal 1, arrangement.arrangement_items.count
    assert_equal 1, item.service_occurrences.count
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.created", subject_id: arrangement.id).count
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.item_setup_created", subject_id: arrangement.id
    ).count

    replay = CreateCruiseSailingSetup.new(**arguments).call
    assert_equal :replayed, replay.status
    assert_equal arrangement.id, replay.record.arrangement.id
    assert_equal item.id, replay.record.item.id
    assert_equal occurrence.id, replay.record.occurrence.id
    assert_equal 1, AuditEvent.where(action: "supplier_arrangement.created", subject_id: arrangement.id).count
    assert_equal 1, SupplierArrangement.where(agency: @agency, name: "Celebrity group agreement").count
  end

  test "cruise sailing create rolls back when occurrence dates are invalid" do
    error = assert_raises(AgencyCommand::Error) do
      CreateCruiseSailingSetup.new(
        **sailing_arguments(idempotency_key: "cruise-sailing-invalid").merge(
          occurrence_attributes: sailing_occurrence_attributes.merge(
            starts_on: "2027-11-13",
            ends_on: "2027-11-06"
          )
        )
      ).call
    end

    assert_equal :invalid, error.code
    assert_equal 0, SupplierArrangement.where(agency: @agency, name: "Celebrity group agreement").count
    assert_not AgencyCommandIdempotencyKey.exists?(
      command_name: "CreateCruiseSailingSetup",
      idempotency_key: "cruise-sailing-invalid"
    )
  end

  test "cabin category create is atomic and leaves no orphan resource when pool fails" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    before_resources = arrangement.supplier_resources.count

    error = assert_raises(AgencyCommand::Error) do
      CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @actor,
        arrangement: arrangement,
        resource_attributes: {
          name: "Prime Oceanview",
          supplier_code: "O1",
          maximum_occupancy: 3
        },
        pool_attributes: {
          inventory_mode: "block",
          proposed_opening_quantity: 8,
          evidence_kind: "",
          evidence_on: "",
          evidence_reference_note: "",
          evidence_external_reference: "orphan-reference"
        },
        version_lock_version: version.lock_version,
        idempotency_key: "cabin-orphan"
      ).call
    end

    assert_equal :invalid, error.code
    assert_equal before_resources, arrangement.supplier_resources.count
    assert_equal 0, arrangement.capacity_pools.count
    assert_empty version.capacity_pair_definitions
    assert_not AgencyCommandIdempotencyKey.exists?(
      command_name: "CreateCruiseCabinCategorySetup",
      idempotency_key: "cabin-orphan"
    )
  end

  test "cabin category create is idempotent with optional evidence and fixed pool identity" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    attributes = {
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: " O1 ",
        maximum_occupancy: 3,
        description: ""
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: "cabin-create-1"
    }

    created = CreateCruiseCabinCategorySetup.new(**attributes).call
    assert_equal :created, created.status
    pool = created.record.pool
    resource = created.record.resource
    definition = version.supplier_resource_definitions.find_by!(supplier_resource: resource)
    pool_definition = version.capacity_pool_definitions.find_by!(capacity_pool: pool)

    assert_equal "O1", definition.supplier_code
    assert_equal 3, definition.maximum_occupancy
    assert_equal "resource_units", pool.measurement_basis
    assert_equal "cabins", pool_definition.unit_label
    assert_equal "block", pool.inventory_mode
    assert_equal 8, pool_definition.proposed_opening_quantity
    assert_nil pool_definition.evidence_kind
    assert_equal "America/New_York", pool.effective_time_zone
    assert_predicate version.capacity_pair_definitions.sole, :pooled?

    replay = CreateCruiseCabinCategorySetup.new(**attributes).call
    assert_equal :replayed, replay.status
    assert_equal pool.id, replay.record.pool.id
    assert_equal resource.id, replay.record.resource.id
    assert_equal 1, arrangement.supplier_resources.count
    assert_equal 1, AuditEvent.where(
      action: "supplier_arrangement.capacity_pair_pool_configured",
      subject_id: arrangement.id
    ).count
  end

  test "supplier_code is unique case-insensitively within version and item" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    create_cabin(arrangement, version, code: "O1", key: "cabin-unique-1")

    error = assert_raises(AgencyCommand::Error) do
      create_cabin(arrangement, version.reload, code: "o1", key: "cabin-unique-2", name: "Other")
    end
    assert_equal :invalid, error.code
    assert_equal 1, version.supplier_resource_definitions.where.not(supplier_code: nil).count
  end

  test "partial evidence is rejected while blank evidence remains optional" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole

    create_cabin(arrangement, version, code: "O2", key: "cabin-no-evidence")

    error = assert_raises(AgencyCommand::Error) do
      CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @actor,
        arrangement: arrangement,
        resource_attributes: { name: "Partial evidence cabin", supplier_code: "O3" },
        pool_attributes: {
          inventory_mode: "allotment",
          proposed_opening_quantity: 4,
          evidence_kind: "contract",
          evidence_on: "",
          evidence_reference_note: ""
        },
        version_lock_version: version.reload.lock_version,
        idempotency_key: "cabin-partial-evidence"
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/complete supplier evidence/i, error.message)
  end

  test "typed cabin update refuses pool identity mutation" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin(arrangement, version, code: "O1", key: "cabin-update-1")
    resource_definition = version.supplier_resource_definitions.find_by!(
      supplier_resource: cabin.record.resource
    )
    pool_definition = version.capacity_pool_definitions.find_by!(
      capacity_pool: cabin.record.pool
    )

    error = assert_raises(AgencyCommand::Error) do
      UpdateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @actor,
        arrangement: arrangement,
        resource: cabin.record.resource,
        resource_attributes: { name: "Prime Oceanview Updated", supplier_code: "O1", maximum_occupancy: 4 },
        pool_attributes: {
          proposed_opening_quantity: 9,
          inventory_mode: "allotment"
        },
        version_lock_version: version.reload.lock_version,
        resource_lock_version: resource_definition.lock_version,
        pool_lock_version: pool_definition.lock_version
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/Inventory mode cannot be changed/i, error.message)
    assert_equal "block", cabin.record.pool.reload.inventory_mode
    assert_equal 8, pool_definition.reload.proposed_opening_quantity
  end

  test "typed cabin update changes resource and pool definition fields" do
    arrangement = create_sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = create_cabin(arrangement, version, code: "O1", key: "cabin-update-2")
    resource_definition = version.supplier_resource_definitions.find_by!(
      supplier_resource: cabin.record.resource
    )
    pool_definition = version.capacity_pool_definitions.find_by!(
      capacity_pool: cabin.record.pool
    )

    result = UpdateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      resource: cabin.record.resource,
      resource_attributes: {
        name: "Prime Oceanview Plus",
        supplier_code: "O1A",
        maximum_occupancy: 4
      },
      pool_attributes: {
        proposed_opening_quantity: 10,
        notes: "Held for Smith"
      },
      version_lock_version: version.reload.lock_version,
      resource_lock_version: resource_definition.lock_version,
      pool_lock_version: pool_definition.lock_version
    ).call

    assert_equal :updated, result.status
    assert_equal "Prime Oceanview Plus", resource_definition.reload.name
    assert_equal "O1A", resource_definition.supplier_code
    assert_equal 4, resource_definition.maximum_occupancy
    assert_equal 10, pool_definition.reload.proposed_opening_quantity
    assert_equal "Held for Smith", pool_definition.notes
    assert_equal "block", cabin.record.pool.reload.inventory_mode
  end

  test "shape detector accepts cruise sailing graphs and rejects advanced shapes" do
    sailing = create_sailing.record
    arrangement = sailing.arrangement
    compatible = DetectCruiseArrangementShape.new(agency: @agency, arrangement: arrangement).call

    assert_predicate compatible, :compatible?
    assert_equal "Celebrity Beyond", compatible.summary["ship_name"]
    assert_equal "Western Caribbean", compatible.summary["sailing_name"]
    assert_equal 0, compatible.cabin_category_count

    version = arrangement.versions.sole
    create_cabin(arrangement, version, code: "O1", key: "cabin-shape-1")
    with_cabin = DetectCruiseArrangementShape.new(agency: @agency, arrangement: arrangement).call
    assert_predicate with_cabin, :compatible?
    assert_equal 1, with_cabin.cabin_category_count

    lodging = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @provider,
      prefix: "Lodging"
    )
    incompatible = DetectCruiseArrangementShape.new(
      agency: @agency,
      arrangement: lodging[:arrangement]
    ).call
    assert_not incompatible.compatible?
    assert_includes incompatible.reasons.join(" "), "cruise"
  end

  test "update sailing keeps contracting supplier immutable and updates ship and dates" do
    sailing = create_sailing.record
    arrangement = sailing.arrangement
    version = arrangement.versions.sole
    item_definition = version.arrangement_item_definitions.sole
    occurrence_definition = version.service_occurrence_definitions.sole

    result = UpdateCruiseSailingSetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      arrangement_attributes: {
        name: "Celebrity group agreement revised",
        supplier_contact_id: @contact.id
      },
      item_attributes: { name: "Celebrity Beyond Suites" },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-13",
        ends_on: "2027-11-20",
        time_zone: "America/New_York"
      },
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: version.lock_version,
      item_lock_version: item_definition.lock_version,
      occurrence_lock_version: occurrence_definition.lock_version
    ).call

    assert_equal :updated, result.status
    assert_equal @contractor.id, arrangement.reload.contracting_supplier_id
    assert_equal "Celebrity group agreement revised", arrangement.name
    assert_equal @contact.id, arrangement.supplier_contact_id
    assert_equal "Celebrity Beyond Suites", item_definition.reload.name
    assert_equal "Eastern Caribbean", occurrence_definition.reload.name
    assert_equal Date.new(2027, 11, 13), occurrence_definition.starts_on
  end

  private

  def sailing_arguments(idempotency_key:)
    {
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: sailing_occurrence_attributes,
      idempotency_key: idempotency_key
    }
  end

  def sailing_occurrence_attributes
    {
      name: "Western Caribbean",
      starts_on: "2027-11-06",
      ends_on: "2027-11-13",
      time_zone: "America/New_York"
    }
  end

  def create_sailing
    CreateCruiseSailingSetup.new(**sailing_arguments(idempotency_key: SecureRandom.uuid)).call
  end

  def create_cabin(arrangement, version, code:, key:, name: "Prime Oceanview")
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      resource_attributes: {
        name: name,
        supplier_code: code,
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: key
    ).call
  end
end
