# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseCompositionSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
  end

  test "staff records cruise sailing and cabin inventory without graph jargon" do
    sign_in_from_browser(@staff)

    visit departure_composition_path(@departure)
    within "nav[aria-label='Composition areas']" do
      click_link "Suppliers"
    end

    assert_selector "a", text: "Set up a Cruise"
    click_link "Set up a Cruise"

    assert_selector "h1.dd-page-title", exact_text: "Set up a Cruise"
    select supplier_option_text(@contractor), from: "Contracting Supplier"
    fill_in "Arrangement name", with: "Celebrity group agreement"
    fill_in "Ship", with: "Celebrity Beyond"
    fill_in "Sailing or itinerary name", with: "Western Caribbean"
    fill_in_html_date "Start date", "2027-11-06"
    fill_in_html_date "End date", "2027-11-13"
    select "America/New_York", from: "Time zone"
    click_button "Save sailing and continue"

    assert_selector "h1.dd-page-title", exact_text: "Celebrity Beyond"
    assert_text "Western Caribbean"
    assert_text "Draft"
    assert_selector "ol.dd-journey-strip .dd-journey-step", count: 5
    assert_text "Agreement and requirements"
    assert_no_text "Commercial benefits"
    assert_no_field "Group creation date"
    assert_selector "#cruise-workspace"
    assert_text "Add cabin categories"
    assert_text "Not recorded"
    assert_text "Activation"
    assert_text "Not ready"
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width, 900)
      assert_selector "#cruise-recommended-next"
      assert_no_page_overflow
    end
    assert_no_text "Arrangement Item"
    assert_no_text "Service Occurrence"
    assert_no_text "Supplier Resource"
    assert_no_text "Capacity Pool"

    within "#cruise-recommended-next" do
      click_link "Add cabin categories"
    end
    within "#cabin-row-0" do
      fill_in "Code", with: "O1"
      fill_in "Cabin category", with: "Prime Oceanview"
      fill_in "Sleeps", with: "3"
      fill_in "Cabins", with: "8"
    end
    click_button "Save cabin categories"

    assert_selector "#cruise-workspace"
    assert_text "Enter Supplier rates"
    assert_text "O1"
    assert_text "Prime Oceanview"
    assert_text "sleeps up to 3"
    assert_text "8 cabins"
    assert_text "Fixed block"

    click_link "Back to Suppliers"
    assert_selector "a", text: "Open Cruise setup"

    arrangement = @departure.supplier_arrangements.find_by!(name: "Celebrity group agreement")
    visit departure_arrangement_path(@departure, arrangement)
    assert_text "Celebrity Beyond"
    assert_text "Prime Oceanview"
  end

  test "staff saves three cabin categories in one save" do
    sign_in_from_browser(@staff)
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: { name: "Celebrity Beyond" },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement

    visit departure_arrangement_cruise_path(@departure, arrangement)
    within "#cruise-recommended-next" do
      click_link "Add cabin categories"
    end
    resize_window(1280, 900)
    assert_selector "table.dd-cabin-table thead", count: 1, visible: :visible
    assert_selector "table.dd-cabin-table tbody tr", count: 3
    resize_window(375, 900)
    assert_selector "table.dd-cabin-table thead", visible: :hidden
    assert_no_page_overflow
    resize_window(1280, 900)
    [
      [ "0", "E3", "Edge Stateroom with Veranda" ],
      [ "1", "O1", "Prime Oceanview" ],
      [ "2", "DI", "Deluxe Inside Stateroom" ]
    ].each do |index, code, name|
      within "#cabin-row-#{index}" do
        fill_in "Code", with: code
        fill_in "Cabin category", with: name
        fill_in "Sleeps", with: "3"
        fill_in "Cabins", with: "8"
      end
    end
    click_button "Save cabin categories"

    assert_text "3 cabin categories saved."
    assert_text "3 · 24 cabins"
    assert_text "E3"
    assert_text "O1"
    assert_text "DI"
  end

  test "staff removes a draft cabin from the summary when removal can finish" do
    sign_in_from_browser(@staff)
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: { name: "Celebrity Beyond" },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    oceanview = add_system_cabin!(arrangement, version, "O1", "Prime Oceanview")
    inside = add_system_cabin!(arrangement, version, "DI", "Deluxe Inside Stateroom")
    definition = version.capacity_pool_definitions.find_by!(supplier_resource: inside.record.resource)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: version.reload,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 5_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-10-13" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ {
          capacity_pool_id: definition.capacity_pool_id,
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: definition.service_occurrence_id,
          supplier_resource_id: definition.supplier_resource_id
        } ]
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    visit departure_arrangement_cruise_path(@departure, arrangement)
    within "#cruise-cabins" do
      within "li", text: "Prime Oceanview" do
        assert_link "Edit"
        assert_button "Remove"
      end
      within "li", text: "Deluxe Inside Stateroom" do
        assert_link "Edit"
        assert_no_button "Remove"
      end
    end
    [ 1280, 375 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
    end

    within "#cruise-cabins li", text: "Prime Oceanview" do
      accept_confirm "Remove this cabin category from the draft?" do
        click_button "Remove"
      end
    end

    assert_text "Cabin category removed."
    assert_no_text "Prime Oceanview"
    assert_text "Deluxe Inside Stateroom"
    assert_not SupplierResource.exists?(oceanview.record.resource.id)
  end

  private

  def add_system_cabin!(arrangement, version, code, name)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: arrangement,
      resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def supplier_option_text(supplier)
    "#{supplier.display_name_for_directory} · #{supplier.supplier_reference}"
  end
end
