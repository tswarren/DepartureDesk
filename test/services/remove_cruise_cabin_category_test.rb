# frozen_string_literal: true

require "test_helper"

class RemoveCruiseCabinCategoryTest < ActiveSupport::TestCase
  include CruiseActivationGateHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
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
    @resource = add_cabin!("O1", "Prime Oceanview").record.resource
  end

  test "a draft cabin with supplier rates can be removed" do
    add_estimate!(@resource)
    assert RemoveCruiseCabinCategory.possible?(version: @version.reload, resource: @resource)

    remove!(@resource)

    assert_not SupplierResource.exists?(@resource.id)
    assert_empty @version.reload.supplier_cost_sources
    assert_empty @version.capacity_pool_definitions
    assert_empty @version.capacity_pair_definitions
    assert_empty @version.supplier_resource_definitions
  end

  test "a deposit reference keeps the category" do
    create_initial_deposit!(@resource)
    @version.reload

    assert_not RemoveCruiseCabinCategory.possible?(version: @version, resource: @resource)
    error = assert_raises(AgencyCommand::Error) { remove!(@resource) }
    assert_equal :dependency_exists, error.code
    assert SupplierResource.exists?(@resource.id)
  end

  test "a successor can remove a new block and keeps the carried category" do
    create_initial_deposit!(@resource)
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    satisfy_cruise_activation_gate!(
      agency: @agency, actor: @actor, arrangement: @arrangement, version: @version.reload
    )
    ActivateSupplierArrangementVersion.new(
      agency: @agency,
      actor: @actor,
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

    successor = CreateCruiseSupplementalBlock.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      arrangement_lock_version: @arrangement.reload.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid,
      maximum_occupancy: 3,
      opening_quantity: 4
    ).call.record
    summary = compile(successor.version)
    carried = summary.cabin_rows.find { |row| row.resource_id == @resource.id }
    supplemental = summary.cabin_rows.find { |row| row.resource_id == successor.resource.id }

    assert_not carried.removable
    assert supplemental.removable

    error = assert_raises(AgencyCommand::Error) do
      remove!(@resource, version: successor.version)
    end
    assert_equal :dependency_exists, error.code
    assert SupplierResource.exists?(@resource.id)

    remove!(successor.resource, version: successor.version.reload)
    assert_not SupplierResource.exists?(successor.resource.id)
    assert SupplierResource.exists?(@resource.id)
    assert successor.version.reload.supplier_resource_definitions.exists?(supplier_resource: @resource)
  end

  private

  def add_cabin!(code, name)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8,
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def add_estimate!(resource)
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: resource,
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
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def create_initial_deposit!(resource)
    definition = @version.capacity_pool_definitions.find_by!(supplier_resource: resource)
    CreateSupplierDepositRequirementDefinition.new(
      agency: @agency,
      actor: @actor,
      version: @version,
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
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def remove!(resource, version: @version)
    RemoveCruiseCabinCategory.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: resource,
      version_lock_version: version.reload.lock_version
    ).call
  end

  def compile(version)
    shape = DetectCruiseArrangementShape.new(
      agency: @agency, arrangement: @arrangement, version: version
    ).call
    CompileCruiseCompositionSummary.new(
      agency: @agency, arrangement: @arrangement, shape: shape
    ).call
  end
end
