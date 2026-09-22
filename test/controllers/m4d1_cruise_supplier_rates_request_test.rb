# frozen_string_literal: true

require "test_helper"

class M4d1CruiseSupplierRatesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin
    @arrangement = @setup[:arrangement]
    @resource = @setup[:resource]
    @version = @arrangement.versions.sole
  end

  test "workspace links to add supplier rates and rate page saves smith terms" do
    sign_in_as @staff

    get departure_arrangement_cruise_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-rates-heading"
    assert_select "a", text: "Add Supplier rates"

    get departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    assert_response :success
    assert_select "#cruise-supplier-rate-terms"
    assert_select "button", text: "Add rate profile"
    assert_select "button", text: "Add component"
    assert_match(/Use the same commission rate for every profile/, response.body)
    assert_select ".dd-cruise-rate-narrow"
    assert_no_match(/\bquantity_basis\b|\bSupplierCost\b/, response.body)

    post preview_departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: {
      version_lock_version: @version.lock_version,
      stage: "estimate",
      profiles: {
        "0" => { family: "first_second", key: "first_second" },
        "1" => { family: "every_traveler", key: "every_traveler" }
      },
      cells: {
        "base_fare:first_second" => "1624.00",
        "nccf:every_traveler" => "320.00"
      },
      commission: { method: "not_provided" }
    }, headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    assert body["illustrations"].is_a?(Array)
    assert body["illustrations"].any?

    post departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: {
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      stage: "estimate",
      profiles: %w[first_second additional every_traveler single_supplement],
      cells: {
        "base_fare:first_second" => "1624.00",
        "base_fare:additional" => "406.00",
        "base_fare:single_supplement" => "1624.00",
        "nccf:every_traveler" => "320.00",
        "discount:first_second" => "150.00",
        "discount:additional" => "37.50",
        "taxes_fees:every_traveler" => "137.00"
      },
      commission: { method: "not_provided" }
    }

    assert_redirected_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    follow_redirect!
    assert_response :success
    assert_match(/\$3,862\.00|386200/, response.body)
    assert_match(/commission pending/i, response.body)
  end

  test "cross-agency supplier rates return not found" do
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
      item_attributes: { name: "Foreign ship" },
      occurrence_attributes: {
        name: "Foreign sailing",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    foreign_arrangement = foreign.record.arrangement
    foreign_version = foreign_arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: other,
      actor: agency_users(:cove_admin),
      arrangement: foreign_arrangement,
      resource_attributes: { name: "Inside", supplier_code: "IN", maximum_occupancy: 2 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 2 },
      version_lock_version: foreign_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_as @staff
    get departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, foreign_arrangement, cabin.record.resource
    )
    assert_response :not_found
  end

  private

  def create_cruise_with_cabin
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    { arrangement: arrangement, resource: cabin.record.resource }
  end
end
