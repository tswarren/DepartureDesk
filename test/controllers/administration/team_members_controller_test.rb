require "test_helper"

module Administration
  class TeamMembersControllerTest < ActionDispatch::IntegrationTest
    test "index contains only the current agency" do
      sign_in_as(users(:one))

      get administration_team_members_path

      assert_response :success
      assert_includes response.body, users(:one).email_address
      assert_not_includes response.body, users(:two).email_address
    end

    test "another agency membership UUID is not found" do
      sign_in_as(users(:one))

      get administration_team_member_path(agency_memberships(:two))
      assert_response :not_found

      post suspend_administration_team_member_path(agency_memberships(:two))
      assert_response :not_found
    end

    test "staff cannot view the team" do
      sign_in_as(users(:two))

      get administration_team_members_path
      assert_redirected_to root_url
    end
  end
end
