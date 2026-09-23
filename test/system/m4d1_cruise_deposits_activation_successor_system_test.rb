# frozen_string_literal: true

require "application_system_test_case"

class M4d1CruiseDepositsActivationSuccessorSystemTest < ApplicationSystemTestCase
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
    @version = @arrangement.versions.sole
    @item = @arrangement.arrangement_items.sole
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
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @resource = cabin.record.resource
    @pool = @version.reload.capacity_pool_definitions.sole.capacity_pool
  end

  test "19.5 definition-level activation preview and activation materialization" do
    create_initial_deposit!
    sign_in_from_browser(@staff)
    visit_deposits_workspace

    assert_selector "#cruise-activation-preview"
    assert_text "Initial deposit"
    assert_text "Opens commitment"
    assert_link "Activate Arrangement"

    activate_cruise!
    visit_deposits_workspace

    assert_no_selector "#cruise-activation-preview"
    assert_text "Governing operational state"
    assert_text "Tranche"
    assert_text "Open"
    refute_text(/\bpaid\b/i)
    assert_equal 1, SupplierDepositRequirementTranche.where(supplier_arrangement: @arrangement).count
    assert_equal 1, SupplierCommitment.where(
      opening_kind: "deposit_requirement",
      supplier_arrangement: @arrangement
    ).count
  end

  test "19.6 earlier-of milestone before fallback replaces due date without duplicate commitment" do
    create_earlier_of_deposit!
    activate_cruise!
    before_count = SupplierCommitment.where(
      opening_kind: "deposit_requirement",
      supplier_arrangement: @arrangement
    ).count

    sign_in_from_browser(@staff)
    visit_deposits_workspace
    fill_in_html_date "Names assigned to supplier on", "2027-02-01"
    click_on "Record names assigned to supplier"
    assert_text "Planning milestone recorded"
    assert_selector "#cruise-deposits-and-deadlines"

    tranche = SupplierDepositRequirementTranche.find_by!(supplier_arrangement: @arrangement)
    assert_equal Date.new(2027, 2, 1), tranche.governing_deadline_occurrence.calculated_on
    assert_equal before_count, SupplierCommitment.where(
      opening_kind: "deposit_requirement",
      supplier_arrangement: @arrangement
    ).count
  end

  test "19.6 earlier-of milestone after fallback preserves historical overdue occurrence" do
    create_earlier_of_deposit!
    activate_cruise!
    tranche = SupplierDepositRequirementTranche.find_by!(supplier_arrangement: @arrangement)
    fallback = tranche.governing_deadline_occurrence
    assert_equal Date.new(2027, 3, 11), fallback.calculated_on

    travel_to Time.zone.parse("2027-03-20 12:00:00") do
      RefreshSupplierDeadlineProjection.call(occurrence: fallback, at: Time.current)
      fallback.reload
      assert fallback.elapsed?

      sign_in_from_browser(@staff)
      visit_deposits_workspace
      fill_in_html_date "Names assigned to supplier on", "2027-03-25"
      click_on "Record names assigned to supplier"
      assert_text "Planning milestone recorded"

      fallback.reload
      assert fallback.current?
      assert_nil fallback.superseded_at
      assert_equal Date.new(2027, 3, 11), fallback.calculated_on
      assert_equal 1, SupplierCommitment.where(
        opening_kind: "deposit_requirement",
        supplier_arrangement: @arrangement
      ).count
    end
  end

  test "19.7 successor compare leaves governing occurrence unchanged" do
    create_initial_deposit!
    activate_cruise!
    governing = SupplierDeadlineOccurrence
      .where(supplier_arrangement: @arrangement, deadline_type: "deposit_due")
      .sole
    due_before = governing.calculated_on

    sign_in_from_browser(@staff)
    visit_deposits_workspace
    click_on "Create successor draft to change future terms"
    visit_deposits_workspace

    assert_text "Successor comparison"
    assert_text "Governing term"
    assert_text "Proposed term"
    assert_text "Reconcile foreshadow"
    assert_text "not yet applied"

    click_on "Edit", match: :first
    select "Fixed date", from: "Timing rule"
    fill_deposit_date "Date", "2027-05-01"
    click_on "Save deposit"
    assert_text "Deposit requirement updated"

    governing.reload
    assert_equal due_before, governing.calculated_on
    assert governing.current?
    assert_text "2027-05-01"
    assert_text "Reconcile foreshadow"
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

  def create_initial_deposit!
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_minor_units: 5_000,
        currency: "USD",
        rule_shape: "fixed_date",
        rule_parameters: { "date" => "2027-01-15" },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: pool_coverage(@pool)
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
  end

  def pool_coverage(pool)
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool_id: pool.id)
    [ {
      capacity_pool_id: pool.id,
      arrangement_item_id: definition.arrangement_item_id,
      service_occurrence_id: definition.service_occurrence_id,
      supplier_resource_id: definition.supplier_resource_id
    } ]
  end

  def create_earlier_of_deposit!
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version,
      attributes: {
        description: "Final deposit",
        amount_shape: "fixed_amount",
        fixed_amount_minor_units: 50_000,
        currency: "USD",
        rule_shape: "earlier_of",
        rule_parameters: {
          "arms" => [
            { "rule_shape" => "fixed_date", "rule_parameters" => { "date" => "2027-03-11" } },
            {
              "rule_shape" => "planning_milestone",
              "rule_parameters" => { "kind" => "names_assigned_to_supplier" }
            }
          ]
        },
        precision: "date_only",
        time_zone: "America/New_York",
        coverage_links: [ { arrangement_item_id: @item.id } ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    @version.reload
  end

  def activate_cruise!
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      arrangement_item: @item,
      charging_supplier: @contractor,
      label: "Entered cruise cost",
      position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_source: source,
      stage: "contracted",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Included in package",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:2bc-system",
      readiness_provenance: "Signed terms"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      committed_supplier: @contractor,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Eight guaranteed cabins",
      fixed_quantity: 8,
      quantity_basis: "resource_units",
      position: 1
    )

    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      version: @version,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
    @version.reload
    @arrangement.reload
  end
end
