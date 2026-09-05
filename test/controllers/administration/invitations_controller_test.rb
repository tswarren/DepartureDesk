require "test_helper"

module Administration
  class InvitationsControllerTest < ActionDispatch::IntegrationTest
    test "staff invitation without offices is rejected" do
      sign_in_as(users(:one))

      assert_no_difference("AgencyMembership.count") do
        post administration_invitations_path, params: {
          invitation_form: {
            email_address: "form-no-office@example.com",
            first_name: "No",
            last_name: "Office",
            role: "staff"
          }
        }
      end

      assert_response :unprocessable_entity
    end

    test "staff invitation with a default office succeeds" do
      sign_in_as(users(:one))
      office = offices(:one)

      post administration_invitations_path, params: {
        invitation_form: {
          email_address: "form-office@example.com",
          first_name: "Has",
          last_name: "Office",
          role: "staff",
          office_ids: [ office.id ],
          default_office_id: office.id
        }
      }

      assert_redirected_to administration_team_members_path
      membership = AgencyMembership.joins(:user).find_by!(users: { email_address: "form-office@example.com" })
      assert_equal office, membership.default_office
    end
  end
end
