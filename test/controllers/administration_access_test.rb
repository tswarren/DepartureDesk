require "test_helper"

class AdministrationAccessTest < ActionDispatch::IntegrationTest
  test "a viewer mutation is rejected" do
    sign_in_as agency_users(:harbor_viewer)
    name = agencies(:harbor).name

    patch administration_agency_path, params: { agency: { name: "Changed Name", lock_version: agencies(:harbor).lock_version } }

    assert_redirected_to root_path
    assert_equal AgencyCommand::UNAUTHORIZED, flash[:alert]
    assert_equal name, agencies(:harbor).reload.name
  end

  test "a rejected user edit does not save a later field" do
    sign_in_as agency_users(:harbor_admin)
    user = agency_users(:harbor_admin)

    patch administration_agency_user_path(user), params: {
      agency_user: {
        access_role: "staff",
        relationship: "Former administrator",
        default_office_id: offices(:harbor_west).id,
        lock_version: user.lock_version
      }
    }

    assert_response :unprocessable_entity
    user.reload
    assert user.role_administrator?
    assert_nil user.relationship
    assert_equal offices(:harbor_main), user.default_office
  end

  test "staff cannot administer users" do
    sign_in_as agency_users(:harbor_staff)

    get administration_agency_users_path
    assert_redirected_to root_path

    assert_no_difference("AgencyUser.count") do
      post administration_agency_users_path, params: {
        agency_user: {
          email_address: "new@example.com",
          first_name: "New",
          last_name: "User",
          access_role: "staff"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "a supplied missing office does not create an invitation" do
    sign_in_as agency_users(:harbor_admin)

    assert_no_difference [ "AgencyUser.count", "AuditEvent.count" ] do
      post administration_agency_users_path, params: invitation_params(default_office_id: SecureRandom.uuid)
    end

    assert_response :not_found
  end

  test "a supplied office from another agency does not create an invitation" do
    sign_in_as agency_users(:harbor_admin)

    assert_no_difference [ "AgencyUser.count", "AuditEvent.count" ] do
      post administration_agency_users_path, params: invitation_params(default_office_id: offices(:cove_main).id)
    end

    assert_response :not_found
  end

  test "an office from another agency is not found" do
    sign_in_as agency_users(:harbor_admin)

    get administration_office_path(offices(:cove_main))
    assert_response :not_found

    get administration_agency_user_path(agency_users(:cove_admin))
    assert_response :not_found

    patch current_office_path, params: { office_id: offices(:cove_main).id }
    assert_response :not_found
    assert_not_equal offices(:cove_main).id, Session.order(:created_at).last.office_id
  end

  test "changing the current office changes no permission" do
    staff = agency_users(:harbor_staff)
    sign_in_as staff

    patch current_office_path, params: { office_id: offices(:harbor_west).id }

    assert_redirected_to root_path
    assert_equal offices(:harbor_west).id, Session.order(:created_at).last.office_id
    assert staff.reload.role_staff?
    assert_not staff.permitted?(:manage_agency_users)
    assert staff.permitted?(:select_office_context)
  end

  test "an agency with no active office still opens the workspace" do
    agencies(:harbor).offices.each do |office|
      ChangeOfficeStatus.new(office: office, actor: agency_users(:harbor_admin), status: "inactive").call
    end
    sign_in_as agency_users(:harbor_admin)

    get root_path

    assert_response :success
    assert_match(/No active office/, response.body)
  end

  test "a query parameter does not select an office" do
    sign_in_as agency_users(:harbor_admin)
    session = Session.order(:created_at).last

    get edit_current_office_path(office_id: offices(:harbor_west).id)

    assert_response :success
    assert_equal offices(:harbor_main).id, session.reload.office_id
  end

  private

  def invitation_params(default_office_id:)
    {
      agency_user: {
        email_address: "new@example.com",
        first_name: "New",
        last_name: "User",
        access_role: "staff",
        default_office_id: default_office_id
      }
    }
  end
end
