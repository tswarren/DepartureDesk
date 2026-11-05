require "test_helper"

class UpdateUserPermissionsTest < ActiveSupport::TestCase
  setup do
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @baseline_staff = agency_users(:harbor_baseline_staff)
  end

  test "an agency admin grants and revokes in one audited save" do
    assert_difference -> { AuditEvent.where(action: "agency_user.permissions_changed").count }, 1 do
      UpdateUserPermissions.new(
        agency_user: @staff, actor: @admin,
        permissions: %w[financial_records supplier_arrangements], lock_version: @staff.lock_version
      ).call
    end

    assert_equal %w[financial_records supplier_arrangements], @staff.reload.granted_permissions.sort
    assert @staff.lock_version.positive?
    event = AuditEvent.where(action: "agency_user.permissions_changed").order(:created_at).last
    assert_equal @staff.id, event.subject_id
    assert_equal %w[financial_records supplier_arrangements], event.details["granted"]
    assert_equal %w[departure_management], event.details["revoked"]
    assert_not @staff.permitted?(:manage_departures)
  end

  test "an unchanged set is a no-op with no audit event" do
    assert_no_difference -> { AuditEvent.count } do
      result = UpdateUserPermissions.new(
        agency_user: @staff, actor: @admin, permissions: %w[departure_management], lock_version: @staff.lock_version
      ).call
      assert_equal :noop, result.status
    end
  end

  test "staff cannot change grants, even their own" do
    [ @staff, @baseline_staff ].each do |actor|
      error = assert_raises(AgencyCommand::Error) do
        UpdateUserPermissions.new(
          agency_user: @baseline_staff, actor:, permissions: %w[financial_records], lock_version: @baseline_staff.lock_version
        ).call
      end
      assert_equal :unauthorized, error.code
    end
    assert_empty @baseline_staff.reload.granted_permissions
  end

  test "an agency admin cannot be given stored grants" do
    error = assert_raises(AgencyCommand::Error) do
      UpdateUserPermissions.new(agency_user: @admin, actor: @admin, permissions: %w[financial_records], lock_version: @admin.lock_version).call
    end
    assert_equal :invalid_state, error.code
  end

  test "unknown permissions and stale lock versions are refused" do
    unknown = assert_raises(AgencyCommand::Error) do
      UpdateUserPermissions.new(agency_user: @staff, actor: @admin, permissions: %w[view_costs], lock_version: @staff.lock_version).call
    end
    assert_equal :invalid, unknown.code

    stale = assert_raises(AgencyCommand::Error) do
      UpdateUserPermissions.new(agency_user: @staff, actor: @admin, permissions: [], lock_version: @staff.lock_version + 1).call
    end
    assert_equal :conflict, stale.code
    assert_equal %w[departure_management], @staff.reload.granted_permissions
  end

  test "the database refuses a grant for a non-staff user or another agency" do
    assert_raises(ActiveRecord::StatementInvalid) do
      UserPermission.transaction(requires_new: true) do
        UserPermission.insert_all!([ { agency_id: @admin.agency_id, agency_user_id: @admin.id, permission: "financial_records", user_type: "agency_admin" } ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      UserPermission.transaction(requires_new: true) do
        UserPermission.insert_all!([ { agency_id: @admin.agency_id, agency_user_id: @admin.id, permission: "financial_records", user_type: "staff" } ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      UserPermission.transaction(requires_new: true) do
        UserPermission.insert_all!([ { agency_id: agencies(:cove).id, agency_user_id: @baseline_staff.id, permission: "financial_records", user_type: "staff" } ])
      end
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      UserPermission.transaction(requires_new: true) do
        UserPermission.insert_all!([ { agency_id: @staff.agency_id, agency_user_id: @staff.id, permission: "view_costs", user_type: "staff" } ])
      end
    end
  end

  test "the database refuses a type change that would leave grants behind" do
    assert_raises(ActiveRecord::StatementInvalid) do
      AgencyUser.transaction(requires_new: true) do
        AgencyUser.where(id: @staff.id).update_all(user_type: "agency_admin")
      end
    end
    assert @staff.reload.staff?
  end

  test "promoting a staff user through the command removes their grants first" do
    ChangeAgencyUserAccess.new(agency_user: @staff, actor: @admin, user_type: "agency_admin", lock_version: @staff.lock_version).call

    assert @staff.reload.agency_admin?
    assert_empty UserPermission.where(agency_user_id: @staff.id)
    event = AuditEvent.where(action: "agency_user.type_changed", subject_id: @staff.id).sole
    assert_equal [ "departure_management" ], event.details["removed_permissions"]
  end
end
