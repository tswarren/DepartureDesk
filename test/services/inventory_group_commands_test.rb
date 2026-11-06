require "test_helper"

# INV-01 to INV-04, INV-12, INV-32, INV-39, SUP-15.
class InventoryGroupCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Groups", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Group Supplier" }, categories: [ "cruise_line" ]).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
  end

  test "a group's representation defaults from its service category and its promise and zone from the arrangement and Departure" do
    { "cruise" => "unit_shells", "air" => "capacity_pool", "activity" => "capacity_pool", "insurance" => "none" }.each do |category, representation|
      group = save!(label: category.humanize, service_category: category).record
      assert_equal representation, group.representation, category
      assert_equal "firm_block", group.availability_promise
      assert_equal "America/New_York", group.time_zone
    end
  end

  test "On request and Rate only groups hold no quantity, in the model and the database (INV-04)" do
    group = save!(label: "Nov 1 Garden Queen", service_category: "hotel", representation: "capacity_pool", availability_promise: "on_request").record
    assert_not group.numeric?
    error = assert_raises(AgencyCommand::Error) { save!(group:, quantity: "2") }
    assert_equal :invalid, error.code
    assert_raises(ActiveRecord::StatementInvalid) do
      InventoryGroup.transaction(requires_new: true) { InventoryGroup.where(id: group.id).update_all(quantity: 2) }
    end
  end

  test "Confirm blockers name each group's missing dates, quantity and positions" do
    save!(label: "V01", service_category: "cruise")
    blockers = @arrangement.reload.confirmation_blockers
    assert_includes blockers, "Enter service dates for V01."
    assert_includes blockers, "Enter how many units or places V01 has."
    assert_includes blockers, "Enter the positions per unit for V01."
  end

  test "a capacity rule names a traveler type that takes part without a position (INV-39)" do
    group = save!(label: "Excursion", service_category: "activity", representation: "unit_shells").record
    child = traveler_types(:harbor_child_0_4)
    SetCapacityRule.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group:, traveler_type_id: child.id, uses_capacity: "0").call
    assert_equal [ child ], group.capacity_rules.map(&:traveler_type)

    cove_type = traveler_types(:cove_adult)
    error = assert_raises(AgencyCommand::Error) do
      SetCapacityRule.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group:, traveler_type_id: cove_type.id, uses_capacity: "0").call
    end
    assert_equal :invalid, error.code
  end

  test "only Supplier arrangements may change inventory, and a Draft group can be removed" do
    group = save!(label: "Remove me", service_category: "meal").record
    refused = assert_raises(AgencyCommand::Error) do
      SaveInventoryGroup.new(agency: @agency, actor: agency_users(:harbor_staff), departure: @departure, arrangement: @arrangement, attributes: { label: "X", service_category: "meal" }).call
    end
    assert_equal :unauthorized, refused.code
    RemoveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group:).call
    assert_empty @arrangement.inventory_groups.reload
  end

  private

  def save!(group: nil, **attributes)
    SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group:, attributes:, lock_version: group&.reload&.lock_version).call
  end
end
