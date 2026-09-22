# frozen_string_literal: true

require "test_helper"

class M4d1CruiseCompositionRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @office = offices(:harbor_main)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
  end

  test "set up cruise create redirects to typed workspace" do
    sign_in_as @staff

    assert_difference -> { @departure.supplier_arrangements.count }, 1 do
      post departure_composition_suppliers_cruises_path(@departure), params: {
        idempotency_key: SecureRandom.uuid,
        arrangement: {
          name: "Celebrity group agreement",
          contracting_supplier_id: @contractor.id
        },
        item: { name: "Celebrity Beyond" },
        occurrence: {
          name: "Western Caribbean",
          starts_on: "2027-11-06",
          ends_on: "2027-11-13",
          time_zone: "America/New_York"
        },
        commit: "Save sailing and continue"
      }
    end

    arrangement = @departure.supplier_arrangements.find_by!(name: "Celebrity group agreement")
    assert_redirected_to departure_arrangement_cruise_path(@departure, arrangement)
    follow_redirect!
    assert_response :success
    assert_select "#cruise-workspace"
    assert_match "Celebrity Beyond", response.body
    assert_match "Western Caribbean", response.body
    assert_select "a", text: "Add a cabin category"
    assert_no_match(/\bItem\b|\bOccurrence\b|\bResource\b|\bPool\b/, response.body)
  end

  test "add cabin category appears on cruise workspace" do
    sign_in_as @staff
    arrangement = create_cruise_sailing.record.arrangement
    version = arrangement.versions.sole

    post departure_arrangement_cruise_cabin_categories_path(@departure, arrangement), params: {
      idempotency_key: SecureRandom.uuid,
      version_lock_version: version.lock_version,
      resource: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      commit: "Save category"
    }

    assert_redirected_to departure_arrangement_cruise_path(@departure, arrangement)
    follow_redirect!
    assert_response :success
    assert_match "O1", response.body
    assert_match "Prime Oceanview", response.body
    assert_match "sleeps up to 3", response.body
    assert_match "8 cabins", response.body
    assert_match "Fixed block", response.body
  end

  test "cross-agency cruise routes return not found" do
    other = agencies(:cove)
    foreign_departure = create_capacity_departure(other, name: "Foreign Cruise")
    foreign_supplier = create_capacity_supplier(other, "Foreign Line")
    foreign = CreateCruiseSailingSetup.new(
      agency: other,
      actor: agency_users(:cove_admin),
      departure: foreign_departure,
      arrangement_attributes: {
        name: "Foreign agreement",
        contracting_supplier_id: foreign_supplier.id
      },
      item_attributes: { name: "Foreign Ship" },
      occurrence_attributes: {
        name: "Foreign sailing",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call.record.arrangement

    sign_in_as @staff
    get new_departure_composition_suppliers_cruise_path(foreign_departure)
    assert_response :not_found
    get departure_arrangement_cruise_path(foreign_departure, foreign)
    assert_response :not_found
    get departure_arrangement_cruise_path(@departure, foreign)
    assert_response :not_found
  end

  test "incompatible shape falls open to summary and advanced link" do
    sign_in_as @staff
    lodging = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @contractor,
      prefix: "Lodging"
    )
    arrangement = lodging[:arrangement]

    get departure_arrangement_cruise_path(@departure, arrangement)
    assert_response :success
    assert_select "#cruise-incompatible"
    assert_select "a", text: "Open advanced Supplier planning"
    assert_match "advanced structure", response.body
    assert_select "#cruise-workspace", count: 0
  end

  test "open cruise setup appears for compatible arrangements on suppliers page" do
    sign_in_as @staff
    cruise = create_cruise_sailing.record.arrangement
    lodging = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @contractor,
      provider: @contractor,
      prefix: "Hotel"
    )[:arrangement]

    get suppliers_departure_composition_path(@departure)
    assert_response :success
    assert_select "a", text: "Set up a Cruise"
    assert_select "a[href=?]", departure_arrangement_cruise_path(@departure, cruise), text: "Open Cruise setup"
    assert_select "a[href=?]", departure_arrangement_path(@departure, lodging), text: "Open advanced Arrangement"
    assert_select "a[href=?]", departure_arrangement_cruise_path(@departure, lodging), count: 0
  end

  private

  def create_cruise_sailing
    CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: { name: "Celebrity Beyond" },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
  end
end
