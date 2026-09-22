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
    visit_rates_page

    fill_in "Base Fare · First/Second", with: "1624.00"
    fill_in "Base Fare · Additional", with: "406.00"
    fill_in "Base Fare · Single Supplement", with: "1624.00"
    fill_in "NCCF · Every Traveler", with: "320.00"
    fill_in "Discount · First/Second", with: "150.00"
    fill_in "Discount · Additional", with: "37.50"
    fill_in "Taxes & Fees · Every Traveler", with: "137.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    assert_text "commission pending"
    assert_no_text "quantity_basis"
    assert_no_text "SupplierCostComponent"
  end

  test "staff adds a Child Additional profile column through the page" do
    sign_in_from_browser(@staff)
    visit_rates_page

    add_rate_profile(family: "Additional", category: "Child")
    assert_text "Additional · Child"
    fill_in "Base Fare · Additional · Child", with: "400.00"
    fill_in "Base Fare · Additional", with: "406.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    assert_text "Additional · Child"
    assert_text "Additional"
    assert_field "Base Fare · Additional · Child", with: "400.00"
  end

  test "staff adds Every Cabin and saves a cabin-level component" do
    sign_in_from_browser(@staff)
    visit_rates_page

    within "#cruise-supplier-rate-terms" do
      assert_text "Every Cabin"
    end
    fill_in "Base Fare · Every Cabin", with: "50.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    definition = current_definition
    cabin_component = definition.supplier_cost_components.find_by!(label: "Base Fare", quantity_basis: "resource_units")
    assert_equal 5_000, cabin_component.amount_minor_units
  end

  test "staff removes a profile with values and it does not persist" do
    sign_in_from_browser(@staff)
    visit_rates_page

    add_rate_profile(family: "Bounded positions", from: "4", to: "4", category: "Teen")
    fill_in "Base Fare · Positions 4–4 · Teen", with: "200.00"
    accept_confirm do
      within "[data-cruise-rate-matrix-target='profileList']" do
        find("tr", text: "Positions 4–4").click_button("Remove")
      end
    end
    assert_no_text "Positions 4–4"
    fill_in "Base Fare · First/Second", with: "100.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    labels = current_definition.supplier_cost_participant_categories.pluck(:label)
    refute_includes labels, "Teen"
  end

  test "staff manages a custom credit row before save" do
    sign_in_from_browser(@staff)
    visit_rates_page

    click_on "Add component"
    fill_in "Component description", with: "Shipboard credit"
    select "Supplier charge", from: "Component kind"
    click_on "Save component"
    assert_text "Shipboard credit"

    find("button", text: "Make credit").click
    assert_text "Supplier credit"
    fill_in "Shipboard credit · First/Second", with: "75.00"
    # Credit reduces the advisory subtotal for First/Second once a charge exists
    fill_in "Base Fare · First/Second", with: "100.00"
    assert_text(/\$25\.00|25\.00/)

    accept_confirm do
      within "tr[data-row-key]", text: "Shipboard credit" do
        click_on "Remove"
      end
    end
    assert_no_text "Shipboard credit"

    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"
    assert_text "Supplier rates saved"
    refute current_definition.supplier_cost_components.any? { |c| c.label == "Shipboard credit" }
  end

  test "staff builds family pricing entirely through visible page controls" do
    sign_in_from_browser(@staff)
    visit_rates_page

    # Strip starters we will replace with Adult-scoped and Child columns.
    remove_profile_named("Every Cabin")
    edit_profile_category(named: "First/Second", category: "Adult")
    edit_profile_category(named: "Additional", category: "Adult")
    add_rate_profile(family: "Additional", category: "Child")

    choose "Scope the category-free profile to Adult" if has_field?("Scope the category-free profile to Adult", wait: 1)

    fill_in "Base Fare · First/Second · Adult", with: "1000.00"
    fill_in "Discount · First/Second · Adult", with: "100.00"
    fill_in "Base Fare · Additional · Adult", with: "500.00"
    fill_in "Discount · Additional · Adult", with: "40.00"
    fill_in "Base Fare · Additional · Child", with: "400.00"
    fill_in "Discount · Additional · Child", with: "50.00"
    fill_in "NCCF · Every Traveler", with: "150.00"
    fill_in "Taxes & Fees · Every Traveler", with: "75.00"
    fill_in "Base Fare · Single Supplement", with: "500.00"
    fill_in "Discount · Single Supplement", with: "40.00"

    select "Percentage", from: "Commission method"
    uncheck "Use the same commission rate for every profile"
    fill_in "First/Second · Adult", with: "10" if has_field?("First/Second · Adult", wait: 1)
    # Profile-specific rate inputs use profile labels as field labels
    within "[data-cruise-rate-matrix-target='commissionRates']" do
      all("input.dd-input").each_with_index do |input, index|
        input.fill_in with: (%w[10 5 5 10][index] || "10")
      end
    end

    within "[data-cruise-rate-matrix-target='commissionTreatments']" do
      all("input[type='checkbox']").each do |box|
        check(box[:id]) unless box.checked?
      end
    end

    # Child discount should be Ignore
    within "[data-cruise-rate-matrix-target='commissionTreatments']" do
      row = find("tr", text: /Discount.*Additional · Child/)
      uncheck(row.find("input[type='checkbox']")[:id])
    end

    assert_text "Anonymous occupants by position", wait: 5
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    assert_text "First/Second · Adult"
    assert_text "Additional · Child"
    assert_text(/Single Adult|Double Adult|two adults/i)
  end

  test "narrow-screen profile selector includes newly added columns" do
    sign_in_from_browser(@staff)
    visit_rates_page
    page.current_window.resize_to(390, 844)

    add_rate_profile(family: "Bounded positions", from: "4", to: "5", category: "Child")
    within ".dd-cruise-rate-narrow" do
      assert_select = find("#cruise_rate_profile_select")
      option_texts = assert_select.all("option").map(&:text)
      assert_includes option_texts, "Positions 4–5 · Child"
      assert_select.select "Positions 4–5 · Child"
    end
    assert_field "Base Fare · Positions 4–5 · Child"
  ensure
    page.current_window.resize_to(1400, 900) if page&.current_window
  end

  private

  def visit_rates_page
    visit departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    assert_text "Supplier rate schedule"
    assert_button "Add rate profile"
  end

  def add_rate_profile(family:, category: nil, from: nil, to: nil)
    click_on "Add rate profile"
    select family, from: "Profile family"
    fill_in "Traveler category (optional)", with: category if category
    fill_in "Starting position", with: from if from
    fill_in "Ending position (optional)", with: to if to
    click_on "Add column"
  end

  def edit_profile_category(named:, category:)
    within "[data-cruise-rate-matrix-target='profileList']" do
      find("tr", text: named).click_button("Edit")
    end
    fill_in "Traveler category (optional)", with: category
    click_on "Add column"
  end

  def remove_profile_named(name)
    within "[data-cruise-rate-matrix-target='profileList']" do
      row = find("tr", text: name)
      if row.has_css?("button", text: "Remove")
        # Confirm only when values present; empty profiles skip confirm
        begin
          accept_confirm(wait: 1) { row.click_button("Remove") }
        rescue Capybara::ModalNotFound
          row.click_button("Remove")
        end
      end
    end
  end

  def current_definition
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    shape.definition
  end
end
