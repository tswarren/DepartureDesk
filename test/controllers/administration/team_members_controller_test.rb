require "test_helper"

module Administration
  class TeamMembersControllerTest < ActionDispatch::IntegrationTest
    include ActionMailer::TestHelper

    FOREIGN_MUTATIONS = [
      [ :patch, :role_administration_team_member_path, { role: "staff" } ],
      [ :post, :suspend_administration_team_member_path, {} ],
      [ :post, :reactivate_administration_team_member_path, {} ],
      [ :post, :replace_invitation_administration_team_member_path, {} ],
      [ :post, :revoke_invitation_administration_team_member_path, {} ]
    ].freeze

    test "index contains only the current agency" do
      sign_in_as(users(:one))

      get administration_team_members_path

      assert_response :success
      assert_includes response.body, users(:one).email_address
      assert_not_includes response.body, users(:two).email_address
    end

    test "another agency membership UUID is not found on show" do
      sign_in_as(users(:one))

      get administration_team_member_path(agency_memberships(:two))
      assert_response :not_found
    end

    FOREIGN_MUTATIONS.each do |http_method, path_helper, params|
      test "foreign membership UUID #{path_helper} returns 404 with no side effects" do
        sign_in_as(users(:one))
        membership = agency_memberships(:two)
        snapshot = membership.attributes.slice("status", "role", "invitation_version", "lock_version")
        audits = AuditEvent.count
        intents = DeliveryIntent.count

        assert_no_emails do
          send(http_method, public_send(path_helper, membership), params:)
        end

        assert_response :not_found
        assert_equal snapshot, membership.reload.attributes.slice("status", "role", "invitation_version", "lock_version")
        assert_equal audits, AuditEvent.count
        assert_equal intents, DeliveryIntent.count
      end
    end

    test "invalid role redirects without a server error" do
      sign_in_as(users(:one))
      staff = invite_and_accept

      patch role_administration_team_member_path(staff), params: { role: "superadmin" }

      assert_redirected_to administration_team_member_path(staff)
      assert_equal "That role is not valid.", flash[:alert]
      assert_equal "staff", staff.reload.role
    end

    test "staff cannot view the team" do
      sign_in_as(users(:two))

      get administration_team_members_path
      assert_redirected_to root_url
    end

    private

    def invite_and_accept
      membership = InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "controller-role@example.com",
        role: "staff",
        first_name: "Pat",
        last_name: "Ng"
      ).call.membership

      AcceptInvitation.new(
        token: membership.invitation_token,
        password: "Newpass123!",
        password_confirmation: "Newpass123!"
      ).call.membership
    end
  end
end
