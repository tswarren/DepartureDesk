# frozen_string_literal: true

require "test_helper"

class CompileCruiseCabinInventoryWorkspaceTest < ActiveSupport::TestCase
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
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
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
  end

  test "no categories have no total and no cabin attention" do
    workspace = compile

    assert_equal 0, workspace.category_count
    assert_nil workspace.tracked_cabin_count
    assert_equal 0, workspace.untracked_category_count
    assert_empty workspace.attention_items
    assert_not workspace.advanced?
  end

  test "complete opening authority is a proposed total without cabin attention" do
    add_cabin!(quantity: 8, evidence: true)

    workspace = compile

    assert_equal 1, workspace.category_count
    assert_equal 8, workspace.tracked_cabin_count
    assert_equal 0, workspace.untracked_category_count
    assert_equal :proposed, workspace.quantity_meaning
    assert_empty workspace.attention_items
    assert_equal "8 cabins", workspace.rows.sole.quantity_label
  end

  test "incomplete opening authority is cabin attention and still counts the proposed quantity" do
    cabin = add_cabin!(quantity: 8, evidence: false)

    workspace = compile
    item = workspace.attention_items.sole

    assert_equal :opening_authority_incomplete, item.code
    assert_equal cabin.record.resource.id, item.resource_id
    assert_equal 8, workspace.tracked_cabin_count
  end

  test "nonnumeric inventory is not tracked and is not cabin attention" do
    add_cabin!(inventory_mode: "on_request", evidence: true)
    add_cabin!(name: "Suite", code: "S1", inventory_mode: "externally_managed", evidence: true)

    workspace = compile

    assert_equal 2, workspace.category_count
    assert_nil workspace.tracked_cabin_count
    assert_equal 2, workspace.untracked_category_count
    assert_empty workspace.attention_items
    assert_equal [ "Quantity not tracked", "Quantity not tracked" ], workspace.rows.map(&:quantity_label)
  end

  test "tracked cabins stay distinct from a category whose quantity is not tracked" do
    add_cabin!(quantity: 8, evidence: true)
    add_cabin!(name: "Concierge", code: "C1", inventory_mode: "on_request", evidence: true)

    workspace = compile

    assert_equal 2, workspace.category_count
    assert_equal 8, workspace.tracked_cabin_count
    assert_equal 1, workspace.untracked_category_count
    assert_equal :proposed, workspace.quantity_meaning
    assert_not workspace.advanced?
    assert_not workspace.rows.find { |row| row.code == "O1" }.advanced_rates
  end

  test "an active pool reports current capacity and the original opening separately" do
    cabin = add_cabin!(quantity: 8, evidence: true)
    activate_version!
    RecordCruiseSameTermsCapacityIncrease.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      pool_id: cabin.record.pool.id,
      quantity: 4,
      rate_minor_units: 5_000,
      evidence: {
        evidence_kind: "supplier_confirmation",
        evidence_on: "2026-10-01",
        evidence_reference_note: "Supplier added four O1 cabins"
      },
      idempotency_key: "projection-increase"
    ).call

    workspace = compile
    row = workspace.rows.sole

    assert_equal "Current active capacity: 12 cabins", row.quantity_label
    assert_equal "Original opening quantity: 8 cabins", row.opening_quantity_label
    assert_equal 12, row.quantity
    assert_equal 12, workspace.tracked_cabin_count
    assert_equal :active_capacity, workspace.quantity_meaning
    assert_equal 0, workspace.carried_count
    assert_not row.carried
  end

  test "a carried successor pool is not aggregated" do
    add_cabin!(quantity: 8, evidence: true)
    activate_version!
    open_successor!

    workspace = compile
    row = workspace.rows.sole

    assert workspace.successor
    assert row.carried
    assert_equal "Carried from active terms", row.quantity_label
    assert_equal "Current Supplier capacity: 8 cabins", row.current_capacity_label
    assert_nil row.quantity
    assert_nil workspace.tracked_cabin_count
    assert_nil workspace.quantity_meaning
    assert_equal 1, workspace.carried_count
    assert_equal 0, workspace.proposed_count
  end

  test "a supplemental successor pool stays proposed and is not added to carried inventory" do
    add_cabin!(quantity: 8, evidence: true)
    activate_version!
    successor = open_successor!
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: "Supplemental O1 block", supplier_code: "O1", maximum_occupancy: 3 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 4 },
      version_lock_version: successor.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    workspace = compile
    carried = workspace.rows.find(&:carried)
    supplemental = workspace.rows.reject(&:carried).sole

    assert_equal "Carried from active terms", carried.quantity_label
    assert_equal "Current Supplier capacity: 8 cabins", carried.current_capacity_label
    assert_nil carried.quantity
    assert_equal "4 cabins", supplemental.quantity_label
    assert_equal 4, supplemental.quantity
    assert_equal "Supplemental O1 block", supplemental.name
    assert workspace.successor
    assert_equal 1, workspace.carried_count
    assert_equal 1, workspace.proposed_count
    assert_nil workspace.tracked_cabin_count
    assert_nil workspace.quantity_meaning
  end

  private

  def compile
    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: @arrangement.reload).call
    CompileCruiseCabinInventoryWorkspace.new(agency: @agency, arrangement: @arrangement, shape: shape).call
  end

  def activate_version!
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
    @version.reload
  end

  def open_successor!
    CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement.reload,
      arrangement_lock_version: @arrangement.lock_version,
      version_lock_version: @arrangement.governing_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call.record
  end

  def add_cabin!(name: "Prime Oceanview", code: "O1", quantity: nil, inventory_mode: "block", evidence: false)
    pool_attributes = { inventory_mode: inventory_mode }
    pool_attributes[:proposed_opening_quantity] = quantity if quantity
    if evidence
      pool_attributes.merge!(
        evidence_kind: "contract",
        evidence_on: Date.current,
        evidence_reference_note: "Signed cabin block"
      )
    end
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: name, supplier_code: code, maximum_occupancy: 3 },
      pool_attributes: pool_attributes,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end
end
