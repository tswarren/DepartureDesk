require "test_helper"

class UpdateAgencyUserTest < ActiveSupport::TestCase
  test "role, relationship, and default office commit together as one audit event" do
    user = agency_users(:harbor_staff)

    assert_difference -> { AuditEvent.where(action: "agency_user.updated").count }, 1 do
      UpdateAgencyUser.new(
        agency_user: user,
        actor: agency_users(:harbor_admin),
        access_role: "viewer",
        relationship: "Coordinator",
        default_office_id: offices(:harbor_west).id,
        lock_version: user.lock_version
      ).call
    end

    user.reload
    assert user.role_viewer?
    assert_equal "Coordinator", user.relationship
    assert_equal offices(:harbor_west), user.default_office
    event = AuditEvent.where(action: "agency_user.updated").order(:created_at).last
    assert_equal "viewer", event.details["access_role"]
    assert_equal offices(:harbor_west).id, event.details["default_office_id"]
    assert_equal "Coordinator", event.details["relationship"]
  end

  test "a rejected last-administrator demotion changes nothing" do
    user = agency_users(:harbor_admin)

    assert_no_difference -> { AuditEvent.where(subject_id: user.id).count } do
      error = assert_raises(AgencyCommand::Error) do
        UpdateAgencyUser.new(
          agency_user: user,
          actor: user,
          access_role: "staff",
          relationship: "Former administrator",
          default_office_id: offices(:harbor_west).id,
          lock_version: user.lock_version
        ).call
      end
      assert_equal :last_administrator, error.code
    end

    user.reload
    assert user.role_administrator?
    assert_nil user.relationship
    assert_equal offices(:harbor_main), user.default_office
  end

  test "an office from another agency is not found and changes nothing" do
    user = agency_users(:harbor_staff)

    assert_no_difference -> { AuditEvent.count } do
      error = assert_raises(AgencyCommand::Error) do
        UpdateAgencyUser.new(
          agency_user: user,
          actor: agency_users(:harbor_admin),
          access_role: "staff",
          relationship: "Should not save",
          default_office_id: offices(:cove_main).id,
          lock_version: user.lock_version
        ).call
      end
      assert_equal :not_found, error.code
    end

    assert_nil user.reload.relationship
  end
end
