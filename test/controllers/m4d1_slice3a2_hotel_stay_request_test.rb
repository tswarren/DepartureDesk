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

    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Standard")
    assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    post item_inventory_resources_departure_arrangement_hotel_path(@departure, arrangement, item), params: resource_params("Deluxe")
    post item_inventory_nights_departure_arrangement_hotel_path(@departure, arrangement, item), params: night_params("2027-11-04")
    post item_inventory_nights_departure_arrangement_hotel_path(@departure, arrangement, item), params: night_params("2027-11-05")

    quantities = [ [ "November 4", "Standard", 5 ], [ "November 4", "Deluxe", 2 ], [ "November 5", "Standard", 10 ], [ "November 5", "Deluxe", 5 ] ]
    quantities.each do |night_name, resource_name, quantity|
      night = occurrence_named(item, night_name)
      resource = resource_named(item, resource_name)
      post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params(night, resource, quantity)
      assert_redirected_to item_inventory_departure_arrangement_hotel_path(@departure, arrangement, item)
    end

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
    assert_match "2 room categories · 22 contracted room nights", response.body
    assert_match item.id, response.body

    deluxe_november_4 = pool_named(item, "November 4", "Deluxe")
    patch item_inventory_opening_departure_arrangement_hotel_path(@departure, arrangement, item, deluxe_november_4), params: {
      definition_lock_version: deluxe_november_4.lock_version,
      opening: { proposed_opening_quantity: "0" }
    }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
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
    post item_inventory_nights_departure_arrangement_hotel_path(@departure, arrangement, item), params: night_params("2027-11-04")
    night = occurrence_named(item, "November 4")
    resource = resource_named(item, "Standard")
    post item_inventory_openings_departure_arrangement_hotel_path(@departure, arrangement, item), params: opening_params(night, resource, 5)

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

  def night_params(date)
    {
      idempotency_key: SecureRandom.uuid,
      night: { starts_on: date }
    }
  end

  def opening_params(night, resource, quantity)
    {
      idempotency_key: SecureRandom.uuid,
      opening: {
        service_occurrence_id: night.service_occurrence_id,
        supplier_resource_id: resource.supplier_resource_id,
        proposed_opening_quantity: quantity,
        evidence_kind: "contract",
        evidence_on: "2026-09-30",
        evidence_reference_note: "Hilton group contract"
      }
    }
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
