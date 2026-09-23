# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseSupplierDepositsSystemTest < ApplicationSystemTestCase
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
    [
      [ "Prime Oceanview", "O1", 8 ],
      [ "Veranda", "V1", 16 ]
    ].each do |name, code, qty|
      CreateCruiseCabinCategorySetup.new(
        agency: @agency,
        actor: @staff,
        arrangement: @arrangement,
        resource_attributes: {
          name: name,
          supplier_code: code,
          maximum_occupancy: 3
        },
        pool_attributes: {
          inventory_mode: "block",
          proposed_opening_quantity: qty
        },
        version_lock_version: version.reload.lock_version,
        idempotency_key: SecureRandom.uuid
      ).call
    end
  end

  test "19.1 and 19.2 initial and cumulative final deposits via typed controls" do
    sign_in_from_browser(@staff)
    visit_deposits_workspace

    click_on "Add deposit requirement"
    select "Initial deposit", from: "Template"
    select "Quantity × rate", from: "Amount shape"
    select "Cabin Capacity Pool units", from: "Quantity basis"
    fill_in "Rate per unit (USD)", with: "50"
    check "O1 · pool"
    check "V1 · pool"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2026-09-20"
    assert_text "$1,200.00", wait: 5
    click_on "Add deposit"
    assert_text "Deposit requirement saved"
    assert_text "Initial deposit"
    assert_match(/focus_deposit_id=/, page.current_url)

    click_on "Edit", match: :first
    assert_selector "#cruise-deposit-editor"
    assert_field "Name", with: "Initial deposit"
    assert_checked_field "O1 · pool"
    assert_checked_field "V1 · pool"
    click_on "Cancel"

    click_on "Add deposit requirement"
    select "Final deposit", from: "Template"
    select "Cumulative target", from: "Amount shape"
    fill_in "Rate per unit (USD)", with: "500"
    check "O1 · pool"
    check "V1 · pool"
    check "Initial deposit"
    select "Earlier of…", from: "Timing rule"
    within "#cruise-deposit-arm1" do
      select "Names assigned to Supplier", from: "cruise_deposit[arm1_rule_shape]"
    end
    within "#cruise-deposit-arm2" do
      select "Fixed date", from: "cruise_deposit[arm2_rule_shape]"
      fill_in_html_date "cruise_deposit[arm2_fixed_date]", "2027-03-11"
    end
    assert_text(/Earlier of/i)
    assert_text "$10,800.00", wait: 5
    click_on "Add deposit"
    assert_text "Deposit requirement saved"
    assert_text "Final deposit"
    assert_text(/Cumulative/i)
    assert_no_text "Fixed amount"
  end

  test "19.4 deposit removal and validation recovery" do
    sign_in_from_browser(@staff)
    visit_deposits_workspace

    click_on "Add deposit requirement"
    select "Initial deposit", from: "Template"
    fill_in "Rate per unit (USD)", with: "50"
    check "O1 · pool"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2026-09-20"
    click_on "Add deposit"
    assert_text "Deposit requirement saved"

    accept_confirm(/Remove Initial deposit/i) do
      within "#cruise-deposit-summaries" do
        click_on "Remove"
      end
    end
    assert_text "Deposit requirement removed"
    assert_no_text "Initial deposit"

    click_on "Add deposit requirement"
    select "Other deposit", from: "Template"
    fill_in "Name", with: ""
    select "Fixed amount", from: "Amount shape"
    fill_in "Fixed amount (USD)", with: "100"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2026-09-20"
    click_on "Add deposit"
    assert_selector "#form-error-summary"
    assert_field "Fixed amount (USD)", with: "100"
  end

  test "19.8 advanced percentage sibling remains advanced with typed peer" do
    version = @arrangement.versions.sole
    pool = version.capacity_pool_definitions.order(:id).first.capacity_pool
    definition_row = version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    advanced = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: version,
      attributes: {
        amount_shape: "quantity_times_rate",
        currency: "USD",
        rate_minor_units: 1_000,
        quantity_basis: "capacity_pool_units",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2026-09-20" },
        precision: "date_only",
        time_zone: "America/New_York",
        description: "Percent sibling",
        coverage_links: [ {
          capacity_pool_id: pool.id,
          arrangement_item_id: definition_row.arrangement_item_id,
          service_occurrence_id: definition_row.service_occurrence_id,
          supplier_resource_id: definition_row.supplier_resource_id
        } ]
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    advanced.update_columns(
      amount_shape: "percentage_of_cost_sources",
      quantity_basis: nil,
      rate_minor_units: nil,
      percentage: 10,
      rounding_scope: "aggregate"
    )

    sign_in_from_browser(@staff)
    visit_deposits_workspace
    assert_text "advanced shape"
    assert_text(/Percentage/i)
    assert_link "Open advanced deposits"

    click_on "Add deposit requirement"
    select "Initial deposit", from: "Template"
    fill_in "Rate per unit (USD)", with: "50"
    check "O1 · pool"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2026-09-20"
    click_on "Add deposit"
    assert_text "Deposit requirement saved"
    assert_text "Percent sibling"
    assert_text "Initial deposit"
  end

  test "19.9 keyboard can complete initial deposit" do
    sign_in_from_browser(@staff)
    visit_deposits_workspace
    page.current_window.resize_to(390, 844)

    click_on "Add deposit requirement"
    find_field("Template").send_keys(:tab)
    select "Initial deposit", from: "Template"
    fill_in "Rate per unit (USD)", with: "50"
    check "O1 · pool"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2026-09-20"
    click_on "Add deposit"
    assert_text "Deposit requirement saved"
    assert_match(/\Acruise-deposit-/, page.evaluate_script("document.activeElement && document.activeElement.id"))
  end

  test "changing cumulative to fixed clears contributor submission path" do
    sign_in_from_browser(@staff)
    visit_deposits_workspace

    click_on "Add deposit requirement"
    select "Initial deposit", from: "Template"
    fill_in "Rate per unit (USD)", with: "50"
    check "O1 · pool"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2026-09-20"
    click_on "Add deposit"
    assert_text "Deposit requirement saved"

    click_on "Add deposit requirement"
    select "Final deposit", from: "Template"
    fill_in "Rate per unit (USD)", with: "500"
    check "O1 · pool"
    check "Initial deposit"
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2027-03-11"
    select "Fixed amount", from: "Amount shape"
    assert_selector "[data-cruise-deposit-editor-target='contributorGroup'][hidden]"
    fill_in "Fixed amount (USD)", with: "100"
    select "Entire Cruise Arrangement", from: "Coverage scope"
    click_on "Add deposit"
    assert_text "Deposit requirement saved"
    assert_text(/Fixed/i)
  end

  private

  def visit_deposits_workspace
    visit departure_arrangement_cruise_path(@departure, @arrangement)
    click_on "Open deposits and deadlines"
    assert_selector "#cruise-deposits-and-deadlines"
  end

  def fill_deposit_date(locator, iso_date)
    fill_in_html_date locator, iso_date
    find_field(locator).execute_script(<<~JS)
      this.dispatchEvent(new Event("input", { bubbles: true }));
      this.dispatchEvent(new Event("change", { bubbles: true }));
    JS
  end
end
