require "test_helper"

class InvitationAcceptancesControllerTest < ActionDispatch::IntegrationTest
  test "accepts an invitation and signs the user in" do
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "join@example.com",
      role: "staff",
      first_name: "Lee",
      last_name: "Park",
      **invite_offices
    ).call.membership

    patch invitation_acceptance_path(membership.invitation_token), params: {
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    }

    assert_redirected_to root_url
    assert cookies[:session_id]
    session = membership.user.sessions.last
    assert_equal offices(:one).id, session.office_id
    follow_redirect!
    assert_includes response.body, agencies(:one).name
  end

  test "rejects an invalid token generically" do
    patch invitation_acceptance_path("bad-token"), params: {
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    }

    assert_redirected_to new_session_path
    assert_equal AcceptInvitation::GENERIC_FAILURE, flash[:alert]
  end

  test "password reset does not activate an invited membership" do
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "reset-invite@example.com",
      role: "staff",
      first_name: "Drew",
      last_name: "Ibarra",
      **invite_offices
    ).call.membership
    user = membership.user

    post passwords_path, params: { email_address: user.email_address }
    put password_path(user.password_reset_token), params: {
      password: "Resetpass123!",
      password_confirmation: "Resetpass123!"
    }

    assert membership.reload.invited?
    assert_nil user.reload.usable_agency_membership

    post session_path, params: { email_address: user.email_address, password: "Resetpass123!" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
  end
end
