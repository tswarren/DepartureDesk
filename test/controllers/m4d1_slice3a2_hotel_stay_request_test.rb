# frozen_string_literal: true

require "test_helper"

class M4d1Slice3a2HotelStayRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(time_zone: "America/New_York")
  end

  test "saving a stay keeps a stable item id and records the Hilton stay graph" do
    sign_in_as @staff

    assert_difference -> { @departure.supplier_arrangements.count }, 1 do
      post departure_composition_suppliers_hotels_path(@departure), params: stay_params("Pre-cruise hotel stay")
    end

    item = item_named("Pre-cruise hotel stay")
    assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, item.supplier_arrangement, item)
    follow_redirect!
    assert_response :success
    assert_select "ol.dd-journey-strip .dd-journey-step", count: 3
    assert_select "a", text: "Supplier rates", count: 0
    assert_select "a", text: "Agreement", count: 0
    assert_select "a", text: "Review & activate", count: 0

    version = item.supplier_arrangement.versions.find_by!(status: "draft")
    definition = version.arrangement_item_definitions.find_by!(arrangement_item: item)
    assert_equal "lodging", definition.category
    assert_equal "managed", definition.capacity_management
    stay = version.service_occurrence_definitions.find_by!(arrangement_item: item, name: "Stay")
    assert_equal Date.new(2027, 11, 4), stay.starts_on
    assert_equal Date.new(2027, 11, 6), stay.ends_on
    assert_equal "America/New_York", stay.time_zone
    assert stay.starts_at_local.present?
    assert stay.ends_at_local.present?
    assert_empty version.capacity_pool_definitions.where(service_occurrence_id: stay.service_occurrence_id)

    get departure_arrangement_hotel_path(@departure, item.supplier_arrangement)
    assert_response :success
    assert_match item.id, response.body
  end

  test "an invalid stay rolls the arrangement back" do
    sign_in_as @staff

    assert_no_difference -> { SupplierArrangement.where(agency: @agency).count } do
      post departure_composition_suppliers_hotels_path(@departure), params: stay_params(
        "Pre-cruise hotel stay",
        ends_on: "2027-11-03"
      )
    end

    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
  end

  test "room inventory records four block openings and a second stay leaves them unchanged" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement

    version_id = draft_version(item).id
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_match "Nov 4–6, 2027 · 2 nights", response.body
    assert_no_match(/Nov 1|Nov 2|Nov 3|Nov 5/, response.body)
    assert_equal 1, draft_version(item).service_occurrence_definitions.where(arrangement_item: item).count
    assert_equal 0, draft_version(item).capacity_pool_definitions.count

    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    follow_redirect!
    assert_match "Standard", response.body
    assert_match "Maximum occupancy 4", response.body
    assert_match "Nov 4", response.body
    assert_match "Nov 5", response.body
    assert_match "Edit category", response.body
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Deluxe")

    quantities = [ [ "2027-11-04", "Standard", 5 ], [ "2027-11-04", "Deluxe", 2 ], [ "2027-11-05", "Standard", 10 ], [ "2027-11-05", "Deluxe", 5 ] ]
    quantities.each do |date, resource_name, quantity|
      resource = resource_named(item, resource_name)
      post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params(date, resource, quantity)
      assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    end
    assert_equal version_id, draft_version(item).id

    assert_equal [ 5, 2, 10, 5 ], opening_quantities(item)
    version = draft_version(item)
    stay = version.service_occurrence_definitions.find_by!(arrangement_item: item, name: "Stay")
    version.supplier_resource_definitions.where(arrangement_item: item).each do |resource|
      pair = version.capacity_pair_definitions.find_by!(
        service_occurrence_id: stay.service_occurrence_id,
        supplier_resource_id: resource.supplier_resource_id
      )
      assert_equal "not_applicable", pair.classification
    end
    version.service_occurrence_definitions.where(arrangement_item: item).where.not(name: "Stay").each do |night|
      assert_nil night.starts_at_local
      assert_nil night.ends_at_local
    end

    get departure_arrangement_hotel_path(@departure, arrangement)
    assert_response :success
    assert_match "Standard / 15 contracted room nights", response.body
    assert_match "Deluxe / 7 contracted room nights", response.body
    assert_match "2 room categories · 22 contracted room nights", response.body
    assert_match item.id, response.body

    deluxe_november_4 = pool_named(item, "November 4", "Deluxe")
    patch item_inventory_opening_departure_arrangement_hotel_path(@departure, arrangement, item, deluxe_november_4), params: {
      definition_lock_version: deluxe_november_4.lock_version,
      opening: { proposed_opening_quantity: "0" }
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
    assert_select "input[name='opening[proposed_opening_quantity]'][value='0']"
    assert_equal [ 5, 2, 10, 5 ], opening_quantities(item)

    post departure_arrangement_hotel_stays_path(@departure, arrangement), params: stay_params("Post-cruise hotel stay").except(:arrangement)
    second = item_named("Post-cruise hotel stay")
    assert_not_equal item.id, second.id
    assert_equal [ 5, 2, 10, 5 ], opening_quantities(item)
    get departure_arrangement_hotel_path(@departure, arrangement)
    assert_match item.id, response.body
    assert_match second.id, response.body
  end

  test "viewer cannot save a hotel stay and another agency is not found" do
    sign_in_as agency_users(:harbor_viewer)
    get new_departure_composition_suppliers_hotel_path(@departure)
    assert_response :not_found

    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    sign_in_as agency_users(:harbor_viewer)
    get departure_arrangement_hotel_path(@departure, item.supplier_arrangement)
    assert_response :success
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, item.supplier_arrangement, item), params: resource_params("Standard")
    assert_redirected_to root_path

    foreign = create_capacity_departure(agencies(:cove), name: "Foreign Trip")
    sign_in_as @staff
    get new_departure_composition_suppliers_hotel_path(foreign)
    assert_response :not_found
    sign_in_as agency_users(:cove_admin)
    get departure_arrangement_hotel_path(@departure, item.supplier_arrangement)
    assert_response :not_found
  end

  test "an unsupported pool stays read only and is not rewritten" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    resource = resource_named(item, "Standard")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-04", resource, 5)

    pool_definition = pool_named(item, "November 4", "Standard")
    pool_definition.update!(unit_label: "cabins")
    quantity_before = pool_definition.proposed_opening_quantity
    updated_at = pool_definition.reload.updated_at

    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_match "A room night Pool is not one numeric block measured in rooms.", response.body
    assert_select "a", text: "Item capacity"
    assert_equal quantity_before, pool_definition.reload.proposed_opening_quantity
    assert_equal "cabins", pool_definition.unit_label
    assert_equal updated_at, pool_definition.updated_at
  end

  test "a successor draft is the pinned version and the governing predecessor stays unchanged" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    resource = resource_named(item, "Standard")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-04", resource, 5)

    activated = activate_arrangement!(arrangement)
    predecessor_pool = activated.capacity_pool_definitions.find_by!(label: "November 4 Standard")
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement.reload,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: activated.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    successor_pool = successor.capacity_pool_definitions.find_by!(label: "November 4 Standard")
    patch item_inventory_opening_departure_arrangement_hotel_path(@departure, arrangement, item, successor_pool), params: {
      definition_lock_version: successor_pool.lock_version,
      opening: { proposed_opening_quantity: "8" }
    }
    assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_equal 8, successor_pool.reload.proposed_opening_quantity
    assert_equal 5, predecessor_pool.reload.proposed_opening_quantity
    assert_equal successor.id, successor_pool.supplier_arrangement_version_id
    assert_equal successor.id, arrangement.reload.editable_version.id
  end

  test "hotel uses the sole editable version when a later version is also present" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    resource = resource_named(item, "Standard")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-04", resource, 5)

    governing = activate_arrangement!(arrangement)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement.reload,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: governing.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    successor.arrangement_item_definitions.find_by!(arrangement_item: item).update!(name: "Successor hotel stay")
    later = arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: arrangement.versions.maximum(:version_number) + 1,
      status: "superseded",
      activated_at: 2.days.ago,
      superseded_at: 1.day.ago
    )

    assert_operator later.version_number, :>, successor.version_number
    assert_equal later.id, arrangement.versions.order(:version_number).last.id
    assert_equal successor.id, arrangement.reload.editable_version.id

    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_match "Successor hotel stay", response.body

    successor_pool = successor.capacity_pool_definitions.find_by!(label: "November 4 Standard")
    patch item_inventory_opening_departure_arrangement_hotel_path(@departure, arrangement, item, successor_pool), params: {
      definition_lock_version: successor_pool.lock_version,
      opening: { proposed_opening_quantity: "6" }
    }
    assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_equal 6, successor_pool.reload.proposed_opening_quantity
    assert_equal successor.id, successor_pool.supplier_arrangement_version_id
    assert_equal 5, governing.capacity_pool_definitions.find_by!(label: "November 4 Standard").proposed_opening_quantity
    assert_empty later.capacity_pool_definitions
  end

  test "editable version is the sole draft even when a loaded list would find another draft first" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    governing = activate_arrangement!(arrangement)
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement.reload,
      arrangement_lock_version: arrangement.lock_version,
      version_lock_version: governing.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record

    arrangement.versions.load
    decoy = governing
    decoy.define_singleton_method(:draft?) { true }
    arrangement.association(:versions).target = [ decoy, *arrangement.versions.to_a ]

    assert_equal successor.id, arrangement.editable_version.id
    assert decoy.draft?
    assert_not_equal decoy.id, arrangement.editable_version.id
  end

  test "hotel access does not choose a version by finding a draft" do
    source = Rails.root.join("app/controllers/concerns/hotel_arrangement_access.rb").read
    composition = Rails.root.join("app/controllers/departure_compositions_controller.rb").read

    refute_match(/find \{ \|version\| version\.draft\?/, source)
    refute_match(/find_by\(status: "draft"\)/, source)
    assert_match("editable_version", source)
    refute_match(/find \{ \|row\| row\.draft\?/, composition)
  end

  test "an activated arrangement without a successor is read only" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    activate_arrangement!(arrangement)
    count = arrangement.supplier_resources.count

    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    assert_response :unprocessable_entity
    assert_equal count, arrangement.supplier_resources.reload.count

    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_select "button", text: "Add room category", count: 0
  end

  test "an item with no definition on the pinned version is not found" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    activate_arrangement!(arrangement)
    orphan = arrangement.arrangement_items.create!(agency: @agency, departure: @departure)

    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, orphan)
    assert_response :not_found
  end

  test "missing and wrong stay pairs and bad inventory cells stay isolated" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Deluxe")
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-04", standard, 5)
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-05", deluxe, 5)

    stay = occurrence_named(item, "Stay")
    stay_pair = draft_version(item).capacity_pair_definitions.find_by!(
      service_occurrence_id: stay.service_occurrence_id,
      supplier_resource_id: standard.supplier_resource_id
    )
    stay_pair.destroy!
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_match "The Stay has no room-category classification.", response.body
    assert_select "#hotel-category-#{deluxe.supplier_resource_id} input[name='opening[proposed_opening_quantity]']"
    assert_select "#hotel-category-#{standard.supplier_resource_id} input[name='opening[proposed_opening_quantity]']", count: 0

    ClassifyCapacityPair.new(
      agency: @agency,
      actor: @staff,
      item: item,
      service_occurrence: stay.service_occurrence,
      supplier_resource: standard.supplier_resource,
      classification: "pooled",
      version_lock_version: draft_version(item).lock_version
    ).call
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_match "The Stay is classified for a room category.", response.body

    night = occurrence_named(item, "November 5")
    night.update!(starts_at_local: "16:00", ends_at_local: "16:00")
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_match "A room night has a local time.", response.body
    assert_select "#hotel-cell-2027-11-04-#{deluxe.supplier_resource_id} input[name='opening[proposed_opening_quantity]']"

    night.update!(starts_at_local: nil, ends_at_local: nil)
    inventory_pair = draft_version(item).capacity_pair_definitions.find_by!(
      service_occurrence_id: night.service_occurrence_id,
      supplier_resource_id: deluxe.supplier_resource_id
    )
    inventory_pair.update!(classification: "not_applicable")
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_match "A room night Pool is not one numeric block measured in rooms.", response.body
    assert_equal 5, pool_named(item, "November 4", "Standard").proposed_opening_quantity
    assert_equal 5, pool_named(item, "November 5", "Deluxe").proposed_opening_quantity

    definition = pool_named(item, "November 4", "Standard")
    copy = CapacityPool.create!(definition.capacity_pool.attributes.except("id", "created_at", "updated_at"))
    CapacityPoolDefinition.create!(
      definition.attributes.except("id", "created_at", "updated_at", "lock_version").merge(
        "capacity_pool_id" => copy.id,
        "label" => "November 4 Standard extra",
        "normalized_label" => "november 4 standard extra",
        "position" => definition.position + 1
      )
    )
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_match "A room night Pool is not one numeric block measured in rooms.", response.body
    assert_select "#hotel-cell-2027-11-04-#{deluxe.supplier_resource_id} input[name='opening[proposed_opening_quantity]']"
  end

  test "a pool on the stay, an extra occurrence, and a second pool block the typed editor" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    resource = resource_named(item, "Standard")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-04", resource, 5)
    version = draft_version(item)
    before_occurrences = version.service_occurrence_definitions.where(arrangement_item: item).count
    before_pools = version.capacity_pool_definitions.count

    CreateServiceOccurrence.new(
      agency: @agency,
      actor: @staff,
      item: item,
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        name: "Early night",
        starts_on: "2027-11-01",
        ends_on: "2027-11-01",
        time_zone: "America/New_York"
      }
    ).call
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_match "An extra Service Occurrence cannot be edited here.", response.body
    assert_match "Advanced Supplier planning", response.body
    assert_equal before_occurrences + 1, draft_version(item).service_occurrence_definitions.where(arrangement_item: item).count
    assert_equal before_pools, draft_version(item).capacity_pool_definitions.count

    extra = draft_version(item).service_occurrence_definitions.find_by!(name: "Early night")
    RemoveServiceOccurrence.new(
      agency: @agency,
      actor: @staff,
      occurrence: extra.service_occurrence,
      version_lock_version: draft_version(item).lock_version
    ).call
    stay = occurrence_named(item, "Stay")
    ConfigureCapacityPairWithPool.new(
      agency: @agency,
      actor: @staff,
      item: item,
      service_occurrence: stay.service_occurrence,
      supplier_resource: resource.supplier_resource,
      version_lock_version: draft_version(item).lock_version,
      idempotency_key: SecureRandom.uuid,
      pool_attributes: {
        label: "Stay Standard",
        inventory_mode: "block",
        measurement_basis: "resource_units",
        unit_label: "rooms",
        proposed_opening_quantity: 1,
        evidence_kind: "contract",
        evidence_on: "2026-09-30",
        evidence_reference_note: "Stay pool"
      }
    ).call
    pool_count = draft_version(item).capacity_pool_definitions.count
    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_match "The Stay has a Capacity Pool.", response.body
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-05", resource, 9)
    assert_response :unprocessable_entity
    assert_equal pool_count, draft_version(item).capacity_pool_definitions.count
  end

  test "changing the stay leaves stored nights in place and fails closed when they no longer match" do
    sign_in_as @staff
    item = create_stay("Pre-cruise hotel stay")
    arrangement = item.supplier_arrangement
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    resource = resource_named(item, "Standard")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params("2027-11-04", resource, 5)
    stay = occurrence_named(item, "Stay")
    night_id = occurrence_named(item, "November 4").id

    patch item_stay_departure_arrangement_hotel_path(@departure, arrangement, item), params: {
      definition_lock_version: stay.lock_version,
      occurrence: {
        starts_on: "2027-11-10",
        ends_on: "2027-11-12",
        starts_at_local: "15:00",
        ends_at_local: "12:00",
        time_zone: "America/New_York"
      }
    }
    assert_redirected_to departure_arrangement_hotel_path(@departure, arrangement)
    assert ServiceOccurrenceDefinition.exists?(night_id)
    assert_equal 5, pool_named(item, "November 4", "Standard").proposed_opening_quantity

    get item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    assert_response :success
    assert_match "An extra Service Occurrence cannot be edited here.", response.body
    assert_select "a", text: "Advanced Supplier planning"
  end

  private

  def stay_params(name, ends_on: "2027-11-06")
    {
      idempotency_key: SecureRandom.uuid,
      arrangement: { contracting_supplier_id: @contractor.id },
      item: { name: name },
      occurrence: {
        starts_on: "2027-11-04",
        ends_on: ends_on,
        starts_at_local: "15:00",
        ends_at_local: "12:00",
        time_zone: "America/New_York"
      }
    }
  end

  def resource_params(name)
    {
      idempotency_key: SecureRandom.uuid,
      resource: { name: name, maximum_occupancy: 4 }
    }
  end

  def opening_params(date, resource, quantity)
    {
      idempotency_key: SecureRandom.uuid,
      opening: {
        starts_on: date,
        supplier_resource_id: resource.supplier_resource_id,
        proposed_opening_quantity: quantity,
        evidence_kind: "contract",
        evidence_on: "2026-09-30",
        evidence_reference_note: "Hilton group contract"
      }
    }
  end

  def activate_arrangement!(arrangement)
    @departure.update!(status: "active", departure_reference: "D-930210", first_activated_at: Time.current)
    version = arrangement.versions.find_by!(status: "draft")
    version.update!(status: "activated", activated_at: Time.current)
    arrangement.update!(status: "active", governing_version: version)
    version
  end

  def create_stay(name)
    post departure_composition_suppliers_hotels_path(@departure), params: stay_params(name)
    item_named(name)
  end

  def item_named(name)
    definition = ArrangementItemDefinition.joins(:supplier_arrangement_version).find_by!(
      agency: @agency,
      name: name,
      supplier_arrangement_versions: { status: "draft" }
    )
    definition.arrangement_item
  end

  def draft_version(item)
    item.supplier_arrangement.versions.find_by!(status: "draft")
  end

  def occurrence_named(item, name)
    draft_version(item).service_occurrence_definitions.find_by!(arrangement_item: item, name: name)
  end

  def resource_named(item, name)
    draft_version(item).supplier_resource_definitions.find_by!(arrangement_item: item, name: name)
  end

  def pool_named(item, night_name, resource_name)
    night = occurrence_named(item, night_name)
    resource = resource_named(item, resource_name)
    draft_version(item).capacity_pool_definitions.find_by!(
      service_occurrence_id: night.service_occurrence_id,
      supplier_resource_id: resource.supplier_resource_id
    )
  end

  def opening_quantities(item)
    version = draft_version(item)
    nights = version.service_occurrence_definitions.where(arrangement_item: item).where.not(name: "Stay").order(:starts_on, :id)
    resources = version.supplier_resource_definitions.where(arrangement_item: item).order(:position, :id)
    nights.flat_map do |night|
      resources.map do |resource|
        version.capacity_pool_definitions.find_by!(
          service_occurrence_id: night.service_occurrence_id,
          supplier_resource_id: resource.supplier_resource_id
        ).proposed_opening_quantity
      end
    end
  end
end
