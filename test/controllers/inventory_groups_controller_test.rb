require "test_helper"

class InventoryGroupsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Group Routes", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Excursions" }, categories: [ "activity_attraction" ]).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
  end

  test "an admin adds a group, marks Child 0–4 as not using capacity, and removes the group" do
    sign_in_as @admin
    post departure_arrangement_groups_path(@departure, @arrangement), params: { inventory_group: {
      label: "Private Miami activity", service_category: "activity", representation: "unit_shells", availability_promise: "firm_block",
      quantity: "1", positions_per_unit: "10", starts_on: "2027-11-05", starts_at_time: "14:00", ends_on: "2027-11-05", ends_at_time: "18:30", time_zone: "America/New_York"
    } }
    group = @arrangement.inventory_groups.sole
    assert_redirected_to departure_arrangement_inventory_path(@departure, @arrangement)
    assert_equal 10, group.positions_per_unit

    get departure_arrangement_group_path(@departure, @arrangement, group)
    assert_select "#capacity-rules th", text: "Child 0–4"
    patch departure_arrangement_group_capacity_rule_path(@departure, @arrangement, group), params: { traveler_type_id: traveler_types(:harbor_child_0_4).id, uses_capacity: "false" }
    assert_equal [ traveler_types(:harbor_child_0_4) ], group.capacity_rules.map(&:traveler_type)

    delete departure_arrangement_group_path(@departure, @arrangement, group)
    assert_empty @arrangement.inventory_groups.reload
  end

  test "an invalid group re-renders with field errors" do
    sign_in_as @admin
    post departure_arrangement_groups_path(@departure, @arrangement), params: { inventory_group: { label: "", service_category: "hotel" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get new_departure_arrangement_group_path(@departure, @arrangement)
    assert_response :not_found
  end
end
