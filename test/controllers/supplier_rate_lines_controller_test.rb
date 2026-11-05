require "test_helper"

# S-14, SUP-35, ACC-30, ACC-31.
class SupplierRateLinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Rate Routes", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Alpha Test" }, categories: [ "cruise_line" ]).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
    @group = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { label: "S01", service_category: "cruise", quantity: "8", positions_per_unit: "4" }).call.record
  end

  test "an admin adds, edits and removes a rate on the Draft table" do
    sign_in_as @admin
    get new_departure_arrangement_rate_line_path(@departure, @arrangement)
    assert_response :success
    assert_select "label", text: "Non-commissionable fees"

    post departure_arrangement_rate_lines_path(@departure, @arrangement), params: { supplier_rate_line: {
      inventory_group_id: @group.id, occupancy_position: "guest_3", base_fare: "1,200", discount: "1200", taxes: "189", commission_rate: "14"
    } }
    assert_redirected_to departure_arrangement_path(@departure, @arrangement, anchor: "rate-table")
    line = @arrangement.rate_lines.sole

    get departure_arrangement_path(@departure, @arrangement)
    assert_select "#rate-table th[scope=row]", text: /S01\z/
    assert_select "#rate-table td", text: /3rd guest\z/
    assert_select "#rate-table td", text: /\$1,200\.00\z/
    assert_select "#rate-table td", text: /14%\z/

    get edit_departure_arrangement_rate_line_path(@departure, @arrangement, line)
    assert_select "input[name='supplier_rate_line[base_fare]'][value='1200.00']"
    patch departure_arrangement_rate_line_path(@departure, @arrangement, line), params: { supplier_rate_line: {
      inventory_group_id: @group.id, occupancy_position: "guest_3", base_fare: "1250", discount: "1250", taxes: "189", commission_rate: "14", lock_version: line.lock_version
    } }
    assert_equal 125_000, line.reload.base_fare_minor_units

    delete departure_arrangement_rate_line_path(@departure, @arrangement, line)
    assert_empty @arrangement.rate_lines.reload
  end

  test "an invalid amount re-renders with the error on its field and keeps what was typed" do
    sign_in_as @admin
    post departure_arrangement_rate_lines_path(@departure, @arrangement), params: { supplier_rate_line: {
      inventory_group_id: @group.id, occupancy_position: "guest_1", base_fare: "12.345"
    } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#supplier_rate_line_base_fare']", text: /Base fare must be an amount in USD/
    assert_select "input#supplier_rate_line_base_fare[aria-invalid=true][value='12.345']"
  end

  test "a stale edit is refused" do
    sign_in_as @admin
    line = SaveSupplierRateLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { inventory_group_id: @group.id, occupancy_position: "guest_1", base_fare: "100" }).call.record
    patch departure_arrangement_rate_line_path(@departure, @arrangement, line), params: { supplier_rate_line: {
      inventory_group_id: @group.id, occupancy_position: "guest_1", base_fare: "200", lock_version: line.lock_version + 1
    } }
    assert_response :unprocessable_entity
    assert_equal 10_000, line.reload.base_fare_minor_units
  end

  test "Departure management sees the table but cannot edit it; baseline staff never see it (ACC-31)" do
    SaveSupplierRateLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { inventory_group_id: @group.id, occupancy_position: "guest_1", base_fare: "100" }).call

    sign_in_as agency_users(:harbor_staff)
    get departure_arrangement_path(@departure, @arrangement)
    assert_select "#rate-table td", text: /\$100\.00\z/
    assert_select "#rate-table a", text: "Edit", count: 0
    get new_departure_arrangement_rate_line_path(@departure, @arrangement)
    assert_redirected_to root_path

    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangement_path(@departure, @arrangement)
    assert_response :success
    assert_select "#rate-table", count: 0
    assert_no_match(/\$100\.00/, response.body)
  end

  test "other agencies get not found" do
    line = SaveSupplierRateLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { inventory_group_id: @group.id, occupancy_position: "guest_1", base_fare: "100" }).call.record
    sign_in_as agency_users(:cove_admin)
    get edit_departure_arrangement_rate_line_path(@departure, @arrangement, line)
    assert_response :not_found
  end
end
