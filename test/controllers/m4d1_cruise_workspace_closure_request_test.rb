# frozen_string_literal: true

require "test_helper"

class M4d1CruiseWorkspaceClosureRequestTest < ActionDispatch::IntegrationTest
  include CapacityGraphHelper
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
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
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: provider.id },
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
    @item = sailing.record.item
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: "Prime Oceanview", supplier_code: "O1", maximum_occupancy: 3 },
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
    @pool = cabin.record.pool
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
  end

  test "corrective links stay on the owning workspace" do
    sign_in_as @staff
    get departure_arrangement_cruise_path(@departure, @arrangement)
    assert_select "a#cruise-step-sailing[href=?]",
      edit_departure_arrangement_cruise_sailing_path(@departure, @arrangement)

    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: nil)
    get departure_arrangement_cruise_path(@departure, @arrangement)
    assert_select "a[href=?]",
      edit_departure_arrangement_cruise_cabin_category_path(@departure, @arrangement, @resource.id)
    assert_no_match "#cruise-rates", response.body

    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: 8)
    sources = @version.supplier_cost_sources.where(supplier_resource_id: @resource.id)
    @version.supplier_cost_definitions.where(supplier_cost_source_id: sources.select(:id)).delete_all
    sources.delete_all
    @version.supplier_arrangement_cruise_agreement_confirmations.find_by!(current: true).update_columns(
      status: "provisional", confirmed_at: nil, confirmed_by_id: nil
    )
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select "#cruise-activation-status", text: "Needs attention"
    assert_select "a[href=?]",
      departure_arrangement_cruise_cabin_category_supplier_rates_path(@departure, @arrangement, @resource.id)
    assert_select "a[href=?]",
      departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "agreement")
    assert_no_match "deposits-and-deadlines", response.body
    assert_no_match "#cruise-rates", response.body
  end

  test "review status follows the activation matrix" do
    sign_in_as @staff
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select "#cruise-activation-status", text: "Ready to review"

    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: nil)
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select "#cruise-activation-status", text: "Needs attention"
    @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).update!(proposed_opening_quantity: 8)

    unknown = SupplierArrangementActivationReadiness::Blocker.new(
      track: :structure, code: :items_missing, path: "items", message: "Add at least one Arrangement Item."
    )
    real = SupplierArrangementActivationReadiness.new(
      agency: @agency, arrangement: @arrangement, version: @version.reload
    ).call
    replaced = SupplierArrangementActivationReadiness::Result.new(
      version: real.version, blockers: [ unknown ], cost_selections: real.cost_selections
    )
    readiness = Object.new
    readiness.define_singleton_method(:call) { replaced }
    with_constructor(SupplierArrangementActivationReadiness, readiness) do
      get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    end
    assert_select "#cruise-activation-status", text: "Requires Advanced"
    assert_no_match "The Supplier setup is ready", response.body

    SupplierCostSource.transaction(requires_new: true) do
      source = SupplierCostSource.create!(
        agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
        supplier_arrangement_version: @version.reload, arrangement_item: @item,
        charging_supplier: @contractor, label: "Planning estimate",
        position: @version.supplier_cost_sources.maximum(:position).to_i + 1
      )
      source.supplier_cost_definitions.create!(
        agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
        supplier_arrangement_version: @version, stage: "estimate", status: "forecast_ready",
        mode: "zero_cost", zero_cost_reason: "Planning only", currency: "USD",
        forecast_ready_by: @staff, forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:estimate", readiness_provenance: "Planning"
      )
      get departure_arrangement_cruise_activation_path(@departure, @arrangement)
      assert_select "#cruise-activation-status", text: "Requires Advanced"
      assert_match "The Supplier setup is ready", response.body
      raise ActiveRecord::Rollback
    end

    activate_original!
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select "#cruise-activation-status", text: "Active"
    assert_select ".dd-cruise-version-badge", text: "Active"
    sign_in_as agency_users(:harbor_viewer)
    get departure_arrangement_cruise_active_version_path(@departure, @arrangement)
    assert_response :success
    assert_select "a", text: "Add cabins under same Supplier terms", count: 0
    sign_in_as @staff

    CreateCruiseSupplementalBlock.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      maximum_occupancy: 3,
      opening_quantity: 4,
      supplier_resource_id: @resource.id
    ).call
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select ".dd-cruise-version-badge", text: /Draft · Version/
    assert_select "#cruise-activation-status", text: "Needs attention"
    assert_select "a[href=?]",
      departure_arrangement_cruise_agreement_path(@departure, @arrangement, focus: "agreement")
    assert_no_match "Blocked", response.body
  end

  test "a viewer can read the cruise and cannot change inventory or rates" do
    inside = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: "Deluxe Inside", supplier_code: "DI", maximum_occupancy: 2 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 3,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: inside.record.resource,
      terms: {
        first_second_fare: "1624.00",
        additional_fare: "406.00",
        single_supplement: "1624.00",
        nccf: "320.00",
        first_second_discount: "150.00",
        additional_discount: "37.50",
        taxes_fees: "137.00"
      },
      commission: { method: "not_provided" },
      stage: "contracted",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    sign_in_as agency_users(:harbor_viewer)

    get departure_arrangement_cruise_path(@departure, @arrangement)
    assert_response :success
    assert_select "a#cruise-step-cabins", count: 0
    assert_select "a#cruise-step-rates", count: 0
    assert_select "a#cruise-step-agreement"
    assert_select "a#cruise-step-review"
    hrefs = css_select("#cruise-attention a").map { |link| link["href"] }
    assert_includes hrefs, departure_arrangement_cruise_path(@departure, @arrangement)
    assert hrefs.none? { |href| href.to_s.include?("#cruise-rates") }

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_response :success
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_response :success

    get departure_arrangement_cruise_cabin_categories_path(@departure, @arrangement)
    assert_redirected_to root_path
    get departure_arrangement_cruise_supplier_rates_path(@departure, @arrangement)
    assert_redirected_to root_path
    post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: { capacity_pool_id: @pool.id, quantity: "4", rate_amount: "50.00", idempotency_key: SecureRandom.uuid }
    assert_redirected_to root_path
  end

  private

  def activate_original!
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      version: @version.reload,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Supplier approved exact terms",
        confirmed_without_identifier_reason: "Supplier did not issue one"
      },
      cost_source_coverage_acknowledged: true,
      provisional_costs_acknowledged: false,
      commitment_trigger_coverage_acknowledged: true,
      elapsed_deadlines_acknowledged: true
    ).call
  end

  def with_constructor(klass, replacement)
    singleton = klass.singleton_class
    singleton.alias_method :new_without_closure_stub, :new
    singleton.define_method(:new) { |**| replacement }
    yield
  ensure
    singleton.alias_method :new, :new_without_closure_stub
    singleton.remove_method :new_without_closure_stub
  end
end
