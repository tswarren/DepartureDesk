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
    fill_in "NCCF · First/Second", with: "320.00"
    fill_in "Discount · First/Second", with: "150.00"
    fill_in "Discount · Additional", with: "37.50"
    fill_in "Taxes & Fees · First/Second", with: "137.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    assert_text "Expected commission is not recorded"
    assert_no_text "$0.00"
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
    choose "Scope the category-free profile to Adult"
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

    within ".dd-cruise-rate-matrix thead" do
      assert_no_text "Every Cabin"
    end
    add_rate_profile(family: "Every Cabin")
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
    projected = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.projected_matrix
    profile_keys = Array(projected[:profiles]).map(&:to_s)
    refute profile_keys.any? { |key| key.include?("Teen") }
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
    assert_button "Make charge"
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

  test "unsaved amount updates illustrations before save" do
    sign_in_from_browser(@staff)
    visit_rates_page

    fill_in "Base Fare · First/Second", with: "1624.00"
    fill_in "NCCF · First/Second", with: "100.00"
    select "Not provided yet", from: "Commission method"

    within "[data-cruise-rate-matrix-target='illustrations']" do
      assert_text(/Single occupancy/i, wait: 5)
      assert_no_text(/Illustration preview unavailable/i)
      assert_text(/\$1,?724\.00|1724/, wait: 5)
    end
    assert_no_text "Supplier rates saved"
  end

  test "staff builds family pricing entirely through visible page controls" do
    sign_in_from_browser(@staff)
    visit_rates_page

    edit_profile_category(named: "First/Second", category: "Adult")
    edit_profile_category(named: "Additional", category: "Adult")
    add_rate_profile(family: "Additional", category: "Child")
    add_rate_profile(family: "Every Traveler")

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
    [
      "First/Second · Adult",
      "Additional · Adult",
      "Additional · Child",
      "Every Traveler",
      "Single Supplement"
    ].each do |profile|
      fill_in "Commission rate · #{profile}", with: "10"
    end
    check "Commissionable · Base Fare"
    check "Commissionable · Discount"

    assert_text "Anonymous occupants by position", wait: 5
    select "Child", from: "Position 2"
    within "[data-cruise-rate-matrix-target='illustrations']" do
      assert_text(/Adult \+ Child/i, wait: 5)
      assert_no_text(/Illustration preview unavailable/i)
    end

    click_on "Save Supplier terms"

    assert_text "Supplier rates saved"
    assert_text "First/Second · Adult"
    assert_text "Additional · Child"
    assert_text(/Single Adult|Adult \+|Double Adult|two adults/i)
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

  test "staff enters canonical commission from the rate table" do
    sign_in_from_browser(@staff)
    visit_rates_page
    page.current_window.resize_to(1280, 900)

    within ".dd-cruise-rate-matrix thead" do
      assert_text(/First\/Second/i)
      assert_text(/Additional/i)
      assert_text(/Single Supplement/i)
      assert_no_text(/Every Traveler/i)
      assert_no_text(/Every Cabin/i)
    end
    assert_no_page_overflow

    fill_in "Base Fare · First/Second", with: "2533.00"
    fill_in "Discount · First/Second", with: "950.00"
    fill_in "NCCF · First/Second", with: "320.00"
    fill_in "Taxes & Fees · First/Second", with: "134.26"
    select "Percentage", from: "Commission method"
    fill_in "Commission rate · First/Second", with: "15"
    fill_in "Commission rate · Additional", with: "15"
    fill_in "Commission rate · Single Supplement", with: "15"
    check "Commissionable · Base Fare"
    check "Commissionable · Discount"

    assert_selector "[data-cruise-rate-matrix-target='illustrations']", text: "$1,583.00", wait: 15
    within "[data-cruise-rate-matrix-target='illustrations']" do
      assert_text "$237.45"
      assert_no_text "$0.00"
    end

    page.current_window.resize_to(375, 900)
    assert_no_page_overflow
    page.current_window.resize_to(1280, 900)
    click_on "Save Supplier terms"
    assert_text "Supplier rates saved"
    assert_text "$237.45"

    percentage = expected_commission_components.sole
    assert_equal "percentage", percentage.calculation_kind
    assert_in_delta 0.15, percentage.rate.to_f, 0.0001
    percentage_bases = percentage.supplier_cost_component_bases.includes(:base_component).order(:position, :id).map { |link|
      [ link.direction, link.base_component.label ]
    }
    assert_includes percentage_bases, [ "add", "Base Fare" ]
    assert_includes percentage_bases, [ "subtract", "Discount" ]

    select "Dollar amount", from: "Commission method"
    fill_in "Commission · First/Second", with: "25.00"
    dismiss_confirm { click_on "Save Supplier terms" }
    assert_no_text "Supplier rates updated"
    unchanged = expected_commission_components.sole
    assert_equal percentage.id, unchanged.id
    assert_equal "percentage", unchanged.calculation_kind
    assert_in_delta 0.15, unchanged.rate.to_f, 0.0001
    assert_equal percentage_bases, unchanged.supplier_cost_component_bases.includes(:base_component).order(:position, :id).map { |link|
      [ link.direction, link.base_component.label ]
    }

    visit_rates_page
    assert_equal "percentage", selected_commission_method
    assert_field "Commission rate · First/Second", with: "15"
    assert_checked_field "Commissionable · Base Fare"
    assert_checked_field "Commissionable · Discount"

    select "Dollar amount", from: "Commission method"
    fill_in "Commission · First/Second", with: "25.00"
    accept_confirm { click_on "Save Supplier terms" }
    assert_text "Supplier rates updated"
    dollar_commissions = expected_commission_components
    assert dollar_commissions.all? { |component|
      component.calculation_kind == "unit_rate" && component.rate.nil? && component.supplier_cost_component_bases.none?
    }
    assert_equal [ 2_500 ], dollar_commissions.map(&:amount_minor_units)
    assert_nil SupplierCostComponent.find_by(id: percentage.id)

    visit_rates_page
    assert_equal "dollar", selected_commission_method
    assert_field "Commission · First/Second", with: "25.00"
    assert_no_field "Commission rate · First/Second"
    assert_no_field "Commissionable · Base Fare"
    reopened = expected_commission_components
    assert reopened.all? { |component|
      component.calculation_kind == "unit_rate" && component.supplier_cost_component_bases.none?
    }
  ensure
    page.current_window.resize_to(1400, 900) if page&.current_window
  end

  test "staff records contracted rates without changing the estimate" do
    sign_in_from_browser(@staff)
    visit_rates_page
    fill_in "Base Fare · First/Second", with: "1624.00"
    select "Not provided yet", from: "Commission method"
    click_on "Save Supplier terms"
    assert_text "Supplier rates saved"

    click_on "Record contracted rates from Estimate"
    assert_text "Contracted rates recorded. The estimate is unchanged."
    assert_text "Contracted"
    click_on "Estimate"
    assert_field "Base Fare · First/Second", with: "1624.00"
  end

  test "supplier rates landing and matrix do not overflow the page" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_cruise_supplier_rates_path(@departure, @arrangement)
    assert_text "1 cabin category · 1 not recorded"
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
    end

    visit_rates_page
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
    end
    assert_selector "#cruise-supplier-rate-terms"
    assert_text "Forecast occupancy"
    assert_text "It does not assign travelers or reserve cabins."
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

  def remove_profile_named(name)
    list = "[data-cruise-rate-matrix-target='profileList']"
    return unless has_css?("#{list} tbody tr", text: name, wait: 1)

    begin
      accept_confirm(wait: 1) do
        within(list) { find("tbody tr", text: name).click_button("Remove") }
      end
    rescue Capybara::ModalNotFound
      # Click already ran; only click again if the profile is still present.
      if has_css?("#{list} tbody tr", text: name, wait: 0)
        within(list) { find("tbody tr", text: name).click_button("Remove") }
      end
    end
    assert_no_selector "#{list} tbody tr", text: name, wait: 2
  end

  def edit_profile_category(named:, category:)
    within "[data-cruise-rate-matrix-target='profileList']" do
      find("tbody tr", text: named).click_button("Edit")
    end
    fill_in "Traveler category (optional)", with: category
    click_on "Add column"
  end

  def current_definition
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    shape.definition
  end

  def expected_commission_components
    current_definition.supplier_cost_components.where(economic_role: "expected_commission").order(:position, :id)
  end

  def selected_commission_method
    find_field("Commission method").value
  end
end
