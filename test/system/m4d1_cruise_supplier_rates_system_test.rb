# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseSupplierRatesSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
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
    @arrangement = sailing.record.arrangement
    version = @arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
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
    @resource = cabin.record.resource
  end

  test "staff enters supplier rates without cost graph vocabulary" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )

    fill_in "Base Fare · First/Second", with: "1624.00"
    fill_in "Base Fare · Additional", with: "406.00"
    fill_in "Base Fare · Single Supplement", with: "1624.00"
    fill_in "NCCF · Every Traveler", with: "320.00"
    fill_in "Discount · First/Second", with: "150.00"
    fill_in "Discount · Additional", with: "37.50"
    fill_in "Taxes & Fees · Every Traveler", with: "137.00"
    choose "Not provided yet"
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    assert_text "commission pending"
    assert_no_text "quantity_basis"
    assert_no_text "SupplierCostComponent"
  end
end
