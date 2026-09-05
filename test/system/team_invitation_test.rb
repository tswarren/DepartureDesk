require "application_system_test_case"

class TeamInvitationTest < ApplicationSystemTestCase
  test "administrator invites someone who then joins" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    click_link "Administration"
    click_link "Team"
    click_link "Invite someone"
    fill_in "Email address", with: "system.join@example.com"
    fill_in "First name", with: "Morgan"
    fill_in "Last name", with: "Ellis"
    select "staff", from: "Role"
    check "Sunrise Travel (MAIN)"
    select "Sunrise Travel (MAIN)", from: "Default office"
    click_button "Send invitation"

    assert_text MembershipCommand::ELIGIBLE_INVITE_NOTICE

    membership = AgencyMembership.joins(:user).find_by!(users: { email_address: "system.join@example.com" })
    visit edit_invitation_acceptance_path(membership.invitation_token)
    fill_in "Password", with: "Newpass123!"
    fill_in "Password confirmation", with: "Newpass123!"
    click_button "Join DepartureDesk"

    assert_text "Dashboard"
    assert_text agencies(:one).name
  end
end
