# frozen_string_literal: true

require "test_helper"

class M4d1CruiseDepositsActivationRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin
    @arrangement = @setup[:arrangement]
    @resource = @setup[:resource]
    @version = @arrangement.versions.sole
    @item = @arrangement.arrangement_items.sole
    @pool = @version.capacity_pool_definitions.sole.capacity_pool
  end

  test "staff activation preview is write-free and surfaces definition rows" do
    create_deposit!
    sign_in_as @staff

    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-activation-preview"
    assert_select "#cruise-activation-preview-rows li", minimum: 1
    assert_select "a", text: "Activate Arrangement"

    before_occurrences = SupplierDeadlineOccurrence.count
    before_tranches = SupplierDepositRequirementTranche.count
    before_audits = AuditEvent.count
    before_keys = AgencyCommandIdempotencyKey.count

    post activation_preview_departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    ), params: { version_lock_version: @version.lock_version }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ready", body["status"]
    assert_equal false, body["stale"]
    assert body["rows"].any? { |row| row["kind"] == "deposit" }

    assert_equal before_occurrences, SupplierDeadlineOccurrence.count
    assert_equal before_tranches, SupplierDepositRequirementTranche.count
    assert_equal before_audits, AuditEvent.count
    assert_equal before_keys, AgencyCommandIdempotencyKey.count
  end

  test "activation preview reports stale lock" do
    sign_in_as @staff
    post activation_preview_departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    ), params: { version_lock_version: @version.lock_version - 1 }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "stale", body["status"]
    assert_equal true, body["stale"]
  end

  test "viewer cannot post activation preview" do
    sign_in_as @viewer
    post activation_preview_departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    ), params: { version_lock_version: @version.lock_version }
    assert_redirected_to root_path
  end

  test "other agency arrangement returns not found" do
    sign_in_as @staff
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
    post activation_preview_departure_arrangement_cruise_deposits_and_deadlines_path(
      foreign_departure, foreign.record.arrangement
    ), params: { version_lock_version: 0 }
    assert_response :not_found
  end

  test "active governing page shows operational chrome and milestone form" do
    create_deposit!
    activate_cruise!(@arrangement, @version, @resource)
    sign_in_as @staff

    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-governing-terms-heading"
    assert_match(/Create successor draft to change future terms/, response.body)
    assert_select "#cruise-planning-milestone-heading"
    assert_select "input[name=return_to][value=?]",
      CompileCruiseDepositsAndDeadlinesWorkspace::RETURN_TOKEN
    assert_select "#cruise-activation-preview", count: 0
  end

  test "milestone recording returns to cruise deposits workspace" do
    create_earlier_of_deposit!
    activate_cruise!(@arrangement, @version, @resource)
    sign_in_as @staff

    post departure_arrangement_planning_milestones_path(@departure, @arrangement), params: {
      kind: "names_assigned_to_supplier",
      occurred_on: "2027-02-01",
      note: "Names sent",
      idempotency_key: SecureRandom.uuid,
      return_to: CompileCruiseDepositsAndDeadlinesWorkspace::RETURN_TOKEN
    }
    assert_redirected_to departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    )
  end

  test "successor draft shows compare foreshadow without mutating governing occurrence" do
    create_deposit!
    activate_cruise!(@arrangement, @version, @resource)
    governing_occurrence = SupplierDeadlineOccurrence
      .where(supplier_arrangement: @arrangement, deadline_type: "deposit_due")
      .order(:id)
      .first
    assert governing_occurrence
    governing_occurrence_id = governing_occurrence.id
    governing_due = governing_occurrence.calculated_on

    CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    draft = @arrangement.versions.find_by!(status: "draft")
    deposit = draft.supplier_deposit_requirement_definitions.order(:position, :id).first
    deposit.update_columns(
      rule_parameters: { "date" => "2027-05-01" },
      updated_at: Time.current
    )

    sign_in_as @staff
    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-successor-compare-heading"
    assert_match(/Reconcile foreshadow/, response.body)
    assert_match(/not yet applied/, response.body)
    assert_match(/Will supersede|Will open a commitment|Unchanged/, response.body)

    governing_occurrence.reload
    assert_equal governing_occurrence_id, governing_occurrence.id
    assert_equal governing_due, governing_occurrence.calculated_on
    assert governing_occurrence.current?
  end

  private

  def create_deposit!
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

  def activate_cruise!(arrangement, version, resource)
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    source = SupplierCostSource.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      arrangement_item: arrangement.arrangement_items.sole,
      charging_supplier: @contractor,
      label: "Entered cruise cost",
      position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
      supplier_cost_source: source,
      stage: "contracted",
      status: "forecast_ready",
      mode: "zero_cost",
      zero_cost_reason: "Included in package",
      currency: "USD",
      forecast_ready_by: @staff,
      forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:2bc-activation",
      readiness_provenance: "Signed terms"
    )
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: arrangement,
      supplier_arrangement_version: version,
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
      arrangement: arrangement,
      version: version,
      arrangement_lock_version: arrangement.reload.lock_version,
      version_lock_version: version.reload.lock_version,
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
  end

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
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    { arrangement: arrangement, resource: cabin.record.resource }
  end
end
