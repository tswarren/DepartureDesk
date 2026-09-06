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
      assert_select "nav[aria-label=Administration] a[aria-current=page]", text: "Team"
      assert_select "[aria-invalid=true]"
      assert_select "#invitation_form_office_ids_error"
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
      assert membership.person_party.present?
    end

    test "existing person invitation links the selected unlinked person" do
      sign_in_as(users(:one))
      office = offices(:one)

      post administration_invitations_path, params: {
        invitation_form: {
          email_address: "alex.invite@example.com",
          role: "staff",
          person_source: "existing",
          person_party_id: people(:unlinked).party_id,
          office_ids: [ office.id ],
          default_office_id: office.id
        }
      }

      assert_redirected_to administration_team_members_path
      membership = AgencyMembership.joins(:user).find_by!(users: { email_address: "alex.invite@example.com" })
      assert_equal people(:unlinked).party_id, membership.person_party_id
    end

    test "linked person invitation is rejected" do
      sign_in_as(users(:one))
      office = offices(:one)

      assert_no_difference("AgencyMembership.count") do
        post administration_invitations_path, params: {
          invitation_form: {
            email_address: "linked-person@example.com",
            role: "staff",
            person_source: "existing",
            person_party_id: people(:one).party_id,
            office_ids: [ office.id ],
            default_office_id: office.id
          }
        }
      end

      assert_response :unprocessable_entity
      assert_select "[aria-invalid=true]"
    end
  end
end
