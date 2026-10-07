# frozen_string_literal: true

require "test_helper"

class M4d1CruiseInventoryMaintenanceRequestTest < ActionDispatch::IntegrationTest
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contractor.contacts.sole.id
      },
      item_attributes: { name: "Celebrity Beyond", default_service_provider_id: @provider.id },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    @item = sailing.record.item
    cabin = add_cabin!("O1", "Prime Oceanview", "block", 8)
    @resource = cabin.record.resource
    @pool = cabin.record.pool
    definition = @version.capacity_pool_definitions.find_by!(capacity_pool: @pool)
    @deposit = CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @staff,
      version: @version.reload,
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
          capacity_pool_id: @pool.id,
          arrangement_item_id: definition.arrangement_item_id,
          service_occurrence_id: definition.service_occurrence_id,
          supplier_resource_id: definition.supplier_resource_id
        } ]
      },
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
  end

  test "same terms posts the existing command against the activated version" do
    activate_original!
    sign_in_as @staff
    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    assert_response :success
    assert_match "Active Version #{@version.version_number}", response.body
    assert_select "#cruise-same-terms-capacity", text: /O1 · Prime Oceanview/
    assert_select "#cruise-same-terms-capacity", text: /Current Supplier capacity\s+8\s+cabins/
    increase_form = css_select("#cruise-same-terms-increase").inner_html
    assert_no_match "projection_lock_version", increase_form
    assert_no_match "arrangement_lock_version", increase_form

    assert_no_difference "SupplierArrangementCruiseCapacityDepositRequirement.count" do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(rate_amount: "")
    end
    assert_response :unprocessable_entity
    assert_match "Enter a positive cabin quantity", response.body

    assert_difference "SupplierArrangementCruiseCapacityDepositRequirement.count", 1 do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(idempotency_key: "four-cabins", projection_lock_version: 0)
    end
    follow_redirect!
    assert_match "Current active capacity is 12 cabins.", response.body
    assert_match "Increase deposit $200.00.", response.body
    assert_match "Original opening quantity remains 8.", response.body
    assert_equal 8, @version.capacity_pool_definitions.find_by!(capacity_pool: @pool).proposed_opening_quantity
    assert_equal [ @deposit.id, @deposit.lock_version ], deposit_identity

    assert_difference "SupplierArrangementCruiseCapacityDepositRequirement.count", 1 do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(rate_amount: "0", quantity: "4", idempotency_key: "zero-rate")
    end
    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, @arrangement)
    assert_equal 0, SupplierArrangementCruiseCapacityDepositRequirement.order(:created_at).last.amount_minor_units

    assert_no_difference "SupplierArrangementCruiseCapacityDepositRequirement.count" do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(idempotency_key: "four-cabins")
    end
    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, @arrangement)

    post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: increase_params(idempotency_key: "four-cabins", quantity: "1")
    assert_response :unprocessable_entity
    assert_match "already used for different input", response.body
  end

  test "changed terms posts the supplemental command once and leaves ordinary routes on the draft" do
    activate_original!
    sign_in_as @staff
    assert_difference "SupplierArrangementVersion.count", 1 do
      post changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: supplemental_params
    end
    follow_redirect!
    successor = @arrangement.versions.find_by!(status: "draft")
    supplemental = successor.supplier_resource_definitions.find_by!(name: "Supplemental O1 block")
    pool_definition = successor.capacity_pool_definitions.find_by!(supplier_resource_id: supplemental.supplier_resource_id)

    assert_match "Draft · Version #{successor.version_number}", response.body
    assert_match "Proposed changes to Active Version #{@version.version_number}", response.body
    assert_nil pool_definition.evidence_kind
    assert_nil pool_definition.evidence_on
    assert_nil pool_definition.evidence_reference_note
    assert successor.supplier_arrangement_cruise_agreement_confirmations.none?
    assert_nil successor.supplier_cost_sources.find_by(supplier_resource_id: supplemental.supplier_resource_id)
    assert_no_difference "SupplierArrangementVersion.count" do
      post changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: supplemental_params(idempotency_key: "another-block")
    end
    assert_redirected_to departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)

    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_match "Draft · Version #{successor.version_number}", response.body
    get departure_arrangement_cruise_deposits_and_deadlines_path(@departure, @arrangement)
    assert_match "Draft · Version #{successor.version_number}", response.body
    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_select ".dd-cruise-version-badge", text: "Draft · Version #{successor.version_number}"
    assert_select "#cruise-activation-status", text: "Needs attention"
    get edit_departure_arrangement_cruise_cabin_category_path(@departure, @arrangement, @resource)
    assert_match "Draft · Version #{successor.version_number}", response.body
    get departure_arrangement_cruise_cabin_category_supplier_rates_path(@departure, @arrangement, @resource)
    assert_match "Draft · Version #{successor.version_number}", response.body

    get departure_arrangement_cruise_active_version_path(@departure, @arrangement),
      params: { version_id: successor.id }
    assert_response :success
    assert_select ".dd-cruise-version-badge", text: "Active"
    assert_select "#cruise-setup-nav"
    assert_select "#cruise-active-snapshot a[href=?]",
      departure_arrangement_cruise_agreement_path(@departure, @arrangement), count: 0
    assert_match "Active · Version #{@version.version_number}", response.body
    assert_match "These Supplier terms currently govern.", response.body
    assert_match "View proposed Version #{successor.version_number}", response.body
    assert_no_match "Supplemental O1 block", response.body
    assert_no_match "Confirm and activate group", response.body
    assert_select "a", text: "Open deposits and deadlines", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "a", text: "Add cabins under same Supplier terms", count: 1
    assert_select "a", text: "Propose changed terms", count: 0
  end

  test "same terms shows the selected cabin capacity" do
    inside = add_cabin!("DI", "Deluxe Inside", "block", 3)
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    activate_original!
    sign_in_as @staff

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-same-terms-capacity", text: /O1 · Prime Oceanview/
    assert_select "#cruise-same-terms-capacity", text: /Current Supplier capacity\s+8\s+cabins/
    assert_select "#cruise-same-terms-capacity", text: /Deluxe Inside/, count: 0
    assert_select "#cruise-same-terms-capacity", text: /3 cabins/, count: 0

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: { capacity_pool_id: inside.record.pool.id }
    assert_response :success
    assert_select "#cruise-same-terms-capacity", text: /DI · Deluxe Inside/
    assert_select "#cruise-same-terms-capacity", text: /Current Supplier capacity\s+3\s+cabins/
    assert_select "#cruise-same-terms-capacity", text: /Prime Oceanview/, count: 0
    assert_select "#cruise-same-terms-capacity", text: /8 cabins/, count: 0
    assert_equal inside.record.pool.id, css_select("#cruise-same-terms-increase input[name=capacity_pool_id]").first["value"]
  end

  test "an explicit ineligible pool is not replaced by the first cabin" do
    on_request = add_cabin!("R1", "On request", "on_request", nil).record.pool
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    activate_original!
    sign_in_as @staff

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: { capacity_pool_id: on_request.id }
    assert_response :not_found

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: { capacity_pool_id: SecureRandom.uuid }
    assert_response :not_found

    assert_no_difference -> { @pool.reload.capacity_projection.current_supplier_capacity } do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(capacity_pool_id: on_request.id, commit: "Review this increase", idempotency_key: "review-on-request")
      assert_response :not_found

      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(capacity_pool_id: SecureRandom.uuid, idempotency_key: "record-missing-pool")
      assert_response :not_found
    end
  end

  test "an arbitrary version parameter cannot retarget governing inventory" do
    activate_original!
    sign_in_as @staff
    post changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: supplemental_params
    successor = @arrangement.versions.find_by!(status: "draft")
    foreign_version = { version_id: successor.id, version: successor.version_number }

    get departure_arrangement_cruise_active_version_path(@departure, @arrangement), params: foreign_version
    assert_response :success
    assert_select "#active-terms-heading", text: "Active · Version #{@version.version_number}"
    assert_select "#cruise-active-snapshot", text: /These Supplier terms currently govern/
    assert_select "#cruise-active-snapshot", text: /Supplemental O1 block/, count: 0

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: foreign_version
    assert_response :success
    assert_match "Active Version #{@version.version_number}", response.body
    assert_select "#cruise-same-terms-capacity", text: /Current Supplier capacity\s+8\s+cabins/
    assert_select ".dd-cruise-version-badge", text: "Active"

    assert_no_difference "SupplierArrangementVersion.count" do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(idempotency_key: "ignore-version-selector").merge(
          foreign_version.merge(version_lock_version: successor.lock_version)
        )
    end
    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, @arrangement)
    assert_equal 12, @pool.reload.capacity_projection.current_supplier_capacity
    assert_equal "draft", successor.reload.status
    assert_equal 8, successor.capacity_pool_definitions.find_by!(capacity_pool: @pool).proposed_opening_quantity
    assert_equal @version.id, @arrangement.reload.governing_version_id
  end

  test "same terms while a draft exists changes the live projection and leaves the carried definition" do
    activate_original!
    sign_in_as @staff
    post changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: supplemental_params
    successor = @arrangement.versions.find_by!(status: "draft")
    carried = successor.capacity_pool_definitions.find_by!(capacity_pool: @pool)

    get departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    assert_response :success
    assert_match "This changes the governing Active inventory, not the proposed Draft.", response.body
    assert_match "Proposed Version #{successor.version_number} already exists.", response.body
    assert_select "a", text: "Open Cabin inventory"
    assert_select "a", text: "Propose changed terms", count: 0

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    assert_match "Active Version #{@version.version_number}", response.body
    assert_match "not proposed Draft Version #{successor.version_number}", response.body

    assert_no_difference "SupplierArrangementVersion.count" do
      post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
        params: increase_params(idempotency_key: "carried-increase")
    end
    assert_redirected_to departure_arrangement_cruise_cabin_categories_path(@departure, @arrangement)
    assert_equal 12, @pool.reload.capacity_projection.current_supplier_capacity
    assert_equal 8, carried.reload.proposed_opening_quantity
    follow_redirect!
    assert_match "carried from active terms", response.body
  end

  test "only numeric governing pools are eligible for a same-terms increase" do
    allotment = add_cabin!("A1", "Allotment", "allotment", 2).record.pool
    on_request = add_cabin!("R1", "On request", "on_request", nil).record.pool
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    activate_original!
    sign_in_as @staff
    get departure_arrangement_cruise_active_version_path(@departure, @arrangement)
    assert_match "Quantity not tracked", response.body
    assert_no_match "0 cabins", response.body

    get same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement)
    assert_select "option", text: /O1/
    assert_select "option[value=?]", allotment.id
    assert_select "option[value=?]", on_request.id, count: 0
  end

  test "changed terms for another category stays proposed and off the active snapshot" do
    cabin = add_cabin!("DI", "Deluxe Inside", "block", 8)
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @staff, arrangement: @arrangement, version: @version.reload
    )
    activate_original!
    sign_in_as @staff
    offers = ServiceOffer.count
    post changed_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: supplemental_params(supplier_resource_id: cabin.record.resource.id, idempotency_key: "supplemental-di")
    follow_redirect!
    assert_match "Supplemental DI block", response.body
    assert_match "Proposed · 4 cabins", response.body
    assert_match "Carried from active terms", response.body
    assert_match "Current Supplier capacity:", response.body
    assert_no_match "DI-2", response.body
    assert_no_match "12 cabins", response.body
    assert_equal offers, ServiceOffer.count

    get departure_arrangement_cruise_active_version_path(@departure, @arrangement)
    assert_match "Active · Version #{@version.version_number}", response.body
    assert_no_match "Supplemental DI block", response.body
    assert_no_match "Proposed · 4 cabins", response.body
  end

  test "a viewer can read governing terms and cannot change inventory" do
    activate_original!
    sign_in_as agency_users(:harbor_viewer)
    get departure_arrangement_cruise_active_version_path(@departure, @arrangement)
    assert_response :success
    assert_match "Active · Version #{@version.version_number}", response.body
    assert_select "a", text: "Add cabins under same Supplier terms", count: 0

    post same_terms_departure_arrangement_cruise_inventory_change_path(@departure, @arrangement),
      params: increase_params
    assert_redirected_to root_path
    assert_equal 8, @pool.reload.capacity_projection.current_supplier_capacity
  end

  private

  def add_cabin!(code, name, mode, quantity)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
      pool_attributes: {
        inventory_mode: mode,
        proposed_opening_quantity: quantity,
        evidence_kind: quantity.present? ? "contract" : nil,
        evidence_on: quantity.present? ? Date.current : nil,
        evidence_reference_note: quantity.present? ? "Signed cabin block" : nil
      }.compact,
      version_lock_version: @arrangement.versions.find_by!(status: @version.reload.activated? ? "activated" : "draft").lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

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

  def increase_params(overrides = {})
    {
      capacity_pool_id: @pool.id,
      quantity: "4",
      rate_amount: "50.00",
      effective_on: "",
      evidence_on: Date.current.iso8601,
      evidence_reference_note: "Supplier added four O1 cabins",
      idempotency_key: SecureRandom.uuid,
      commit: "Record capacity increase"
    }.merge(overrides)
  end

  def supplemental_params(overrides = {})
    {
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: "supplemental-o1",
      maximum_occupancy: "3",
      opening_quantity: "4",
      supplier_resource_id: @resource.id
    }.merge(overrides)
  end

  def deposit_identity
    record = @version.supplier_deposit_requirement_definitions.find(@deposit.id)
    [ record.id, record.lock_version ]
  end
end
