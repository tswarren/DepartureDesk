# frozen_string_literal: true

require "test_helper"

class M4d1CruiseSupplierDepositsRequestTest < ActionDispatch::IntegrationTest
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

  test "staff creates typed initial deposit and previews without writes" do
    sign_in_as @staff

    get departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement, deposit_editor: "new"
    )
    assert_response :success
    assert_select "#cruise-deposit-editor"
    assert_select "input[type=checkbox][name='cruise_deposit[capacity_pool_ids][]']"

    lock = @version.lock_version
    audit_before = AuditEvent.count
    definition_before = @version.supplier_deposit_requirement_definitions.count

    post deposit_preview_departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    ), params: {
      version_lock_version: lock,
      request_token: "1",
      cruise_deposit: {
        template: "initial_deposit",
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_amount: "50",
        rule_shape: "fixed_date",
        fixed_date: "2026-09-20",
        capacity_pool_ids: [ @pool.id ]
      }
    }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "ready", body["status"]
    assert_equal 40_000, body["amount_minor_units"]
    assert_equal definition_before, @version.supplier_deposit_requirement_definitions.count
    assert_equal audit_before, AuditEvent.count
    assert_equal lock, @version.reload.lock_version

    assert_difference -> { @version.supplier_deposit_requirement_definitions.count }, 1 do
      post departure_arrangement_cruise_deposits_and_deadlines_deposits_path(
        @departure, @arrangement
      ), params: {
        version_lock_version: @version.lock_version,
        idempotency_key: SecureRandom.uuid,
        cruise_deposit: {
          template: "initial_deposit",
          description: "Initial deposit",
          amount_shape: "quantity_times_rate",
          quantity_basis: "capacity_pool_units",
          rate_amount: "50",
          rule_shape: "fixed_date",
          fixed_date: "2026-09-20",
          capacity_pool_ids: [ @pool.id ]
        }
      }
    end
    assert_response :redirect
    assert_match %r{/cruise/deposits-and-deadlines\?focus_deposit_id=}, @response.redirect_url

    definition = @version.supplier_deposit_requirement_definitions.order(:position, :id).last
    assert_equal "quantity_times_rate", definition.amount_shape
    assert_equal "capacity_pool_units", definition.quantity_basis
    assert_equal 5_000, definition.rate_minor_units
    assert_equal @pool.id, definition.supplier_deposit_requirement_definition_coverage_links.sole.capacity_pool_id

    follow_redirect!
    assert_response :success
    assert_match(/Initial deposit/i, response.body)
  end

  test "viewer cannot mutate and cross-agency is not found" do
    sign_in_as @viewer
    post departure_arrangement_cruise_deposits_and_deadlines_deposits_path(
      @departure, @arrangement
    ), params: {
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      cruise_deposit: {
        template: "initial_deposit",
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_amount: "50",
        rule_shape: "fixed_date",
        fixed_date: "2026-09-20",
        capacity_pool_ids: [ @pool.id ]
      }
    }
    assert_redirected_to root_path
    assert_equal 0, @version.supplier_deposit_requirement_definitions.count

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
    get departure_arrangement_cruise_deposits_and_deadlines_path(
      foreign_departure, foreign.record.arrangement
    )
    assert_response :not_found
  end

  test "stale preview reports staleness without mutating" do
    sign_in_as @staff
    stale_lock = @version.lock_version
    @version.update_column(:lock_version, stale_lock + 1)

    post deposit_preview_departure_arrangement_cruise_deposits_and_deadlines_path(
      @departure, @arrangement
    ), params: {
      version_lock_version: stale_lock,
      request_token: "9",
      cruise_deposit: {
        template: "initial_deposit",
        description: "Initial deposit",
        amount_shape: "quantity_times_rate",
        quantity_basis: "capacity_pool_units",
        rate_amount: "50",
        rule_shape: "fixed_date",
        fixed_date: "2026-09-20",
        capacity_pool_ids: [ @pool.id ]
      }
    }
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "stale", body["status"]
    assert_equal true, body["stale"]
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
