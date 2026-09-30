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
    assert_nil workspace.numeric_total
    assert_empty workspace.attention_items
    assert_not workspace.advanced?
  end

  test "complete opening authority is a proposed total without cabin attention" do
    add_cabin!(quantity: 8, evidence: true)

    workspace = compile

    assert_equal 1, workspace.category_count
    assert_equal 8, workspace.numeric_total
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
    assert_equal 8, workspace.numeric_total
  end

  test "nonnumeric inventory is not tracked and is not cabin attention" do
    add_cabin!(inventory_mode: "on_request", evidence: true)
    add_cabin!(name: "Suite", code: "S1", inventory_mode: "externally_managed", evidence: true)

    workspace = compile

    assert_equal 2, workspace.category_count
    assert_nil workspace.numeric_total
    assert_empty workspace.attention_items
    assert_equal [ "Quantity not tracked", "Quantity not tracked" ], workspace.rows.map(&:quantity_label)
  end

  test "a numeric total ignores nonnumeric categories and does not treat advanced rates as an advanced workspace" do
    add_cabin!(quantity: 8, evidence: true)
    add_cabin!(name: "Concierge", code: "C1", inventory_mode: "on_request", evidence: true)

    workspace = compile

    assert_equal 2, workspace.category_count
    assert_equal 8, workspace.numeric_total
    assert_not workspace.advanced?
    assert_not workspace.rows.find { |row| row.code == "O1" }.advanced_rates
  end

  private

  def compile
    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: @arrangement.reload).call
    CompileCruiseCabinInventoryWorkspace.new(agency: @agency, arrangement: @arrangement, shape: shape).call
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
