require "test_helper"

class SupplierArrangementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Routes", operating_currency: "USD" }).call.record
    @supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Route Supplier" }, categories: [ "lodging" ]).call.record
    @supplier_arrangements = UserPermission.create!(agency: @agency, agency_user: agency_users(:harbor_baseline_staff), permission: "supplier_arrangements", user_type: "staff")
  end

  test "staff with Supplier arrangements create, edit and discard a Draft from the Suppliers tab" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangements_path(@departure)
    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Suppliers"
    assert_select "a", text: "New arrangement"

    post departure_arrangements_path(@departure), params: { supplier_arrangement: { supplier_id: @supplier.id, group_reference: "" } }
    arrangement = @departure.supplier_arrangements.sole
    assert_redirected_to departure_arrangement_path(@departure, arrangement)

    patch departure_arrangement_path(@departure, arrangement), params: { supplier_arrangement: { group_reference: "GRP-1", lock_version: arrangement.lock_version } }
    assert_equal "GRP-1", arrangement.reload.group_reference

    post departure_arrangement_discard_path(@departure, arrangement), params: { lock_version: arrangement.lock_version }
    assert arrangement.reload.cancelled?
  end

  test "staff without Supplier arrangements can view but not change" do
    arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: @supplier.id).call.record
    sign_in_as agency_users(:harbor_staff)
    get departure_arrangement_path(@departure, arrangement)
    assert_response :success
    assert_select "a", text: "Edit arrangement", count: 0
    get new_departure_arrangement_path(@departure)
    assert_redirected_to root_path
  end

  test "a missing supplier re-renders the form with the error" do
    sign_in_as @admin
    post departure_arrangements_path(@departure), params: { supplier_arrangement: { supplier_id: "" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary"
  end

  test "another agency's departure and arrangement are not found" do
    arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: @supplier.id).call.record
    sign_in_as agency_users(:cove_admin)
    get departure_arrangements_path(@departure)
    assert_response :not_found
    get departure_arrangement_path(@departure, arrangement)
    assert_response :not_found
    post departure_arrangement_discard_path(@departure, arrangement), params: { lock_version: arrangement.lock_version }
    assert_response :not_found
    assert arrangement.reload.draft?
  end
end
