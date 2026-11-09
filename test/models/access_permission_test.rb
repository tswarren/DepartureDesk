require "test_helper"

# ADR 0017 catalog matrix: every action for each user type, and for staff with
# and without the grant the action requires.
class AccessPermissionTest < ActiveSupport::TestCase
  BASELINE = %i[
    view_workspace select_office_context
    view_client_directory view_client_contact_details manage_client_directory
    view_supplier_directory view_supplier_contact_details manage_supplier_directory
    view_bookings manage_bookings view_supplier_reservations view_client_money
    view_departures view_arrangements use_tasks
  ].freeze
  ADMIN_ONLY = %i[manage_agency_profile manage_offices manage_agency_users manage_user_permissions].freeze
  GRANTED = { manage_departures: "departure_management", manage_arrangements: "supplier_arrangements", reassign_tasks: "departure_management",
              manage_supplier_reservations: "supplier_arrangements", manage_client_money: "financial_records",
              manage_supplier_payments: "financial_records" }.freeze
  ANY_OF = { view_supplier_costs: %w[departure_management supplier_arrangements financial_records],
             record_amounts_due: %w[supplier_arrangements financial_records],
             override_booking_supplier_cost: %w[supplier_arrangements financial_records],
             confirm_commission: %w[supplier_arrangements financial_records] }.freeze

  test "the catalog covers exactly the listed actions" do
    assert_equal (BASELINE + ADMIN_ONLY + GRANTED.keys + ANY_OF.keys).sort, AccessPermission::CATALOG.keys.sort
  end

  test "agency_admin is allowed every action without grants" do
    AccessPermission::CATALOG.each_key do |action|
      assert AccessPermission.allowed?("agency_admin", [], action), action
    end
  end

  test "staff without grants holds baseline actions only" do
    BASELINE.each { |action| assert AccessPermission.allowed?("staff", [], action), action }
    (ADMIN_ONLY + GRANTED.keys + ANY_OF.keys).each { |action| assert_not AccessPermission.allowed?("staff", [], action), action }
  end

  test "staff with a grant holds the action it unlocks and nothing admin-only" do
    GRANTED.each do |action, permission|
      assert AccessPermission.allowed?("staff", [ permission ], action), action
      others = AccessPermission::PERMISSIONS - [ permission ]
      assert_not AccessPermission.allowed?("staff", others, action), "#{action} with other grants"
    end
    ADMIN_ONLY.each do |action|
      assert_not AccessPermission.allowed?("staff", AccessPermission::PERMISSIONS, action), action
    end
  end

  test "staff holding any one of an action's permissions are allowed it (ACC-31)" do
    ANY_OF.each do |action, permissions|
      permissions.each { |permission| assert AccessPermission.allowed?("staff", [ permission ], action), "#{action} via #{permission}" }
      others = AccessPermission::PERMISSIONS - permissions
      assert_not AccessPermission.allowed?("staff", others, action), action
    end
  end

  test "a reseller satisfies no staff requirement, whatever it holds" do
    AccessPermission::CATALOG.each_key do |action|
      assert_not AccessPermission.allowed?("reseller", AccessPermission::PERMISSIONS, action), action
    end
  end

  test "an unknown user type is refused and an unknown action raises" do
    assert_not AccessPermission.allowed?("viewer", [], :view_workspace)
    assert_raises(KeyError) { AccessPermission.allowed?("agency_admin", [], :no_such_action) }
  end

  test "agency users resolve grants from their rows" do
    assert agency_users(:harbor_staff).permitted?(:manage_departures)
    assert_not agency_users(:harbor_baseline_staff).permitted?(:manage_departures)
    assert agency_users(:harbor_baseline_staff).permitted?(:manage_client_directory)
    assert_not agency_users(:harbor_staff).permitted?(:manage_agency_users)
    assert agency_users(:harbor_admin).permitted?(:manage_user_permissions)
    assert_not agency_users(:harbor_suspended).permitted?(:view_workspace)
  end
end
