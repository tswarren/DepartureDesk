require "application_system_test_case"

class DirectoryPartyFoundationTest < ApplicationSystemTestCase
  test "directory create edit alternate names and existing-person invitation" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    click_link "Directory"
    assert_current_path directory_parties_path
    assert_text "People, households, and organizations"
    assert_text "Alex Morgan"
    assert_text "Morgan Household"
    assert_text "Horizon Tours"

    click_link "Add to directory"
    assert_current_path new_directory_party_path
    assert_text "Choose a kind. Party kind cannot be changed later."
    click_link "Person"
    assert_field "Given name"
    fill_in "Given name", with: "Jamie"
    fill_in "Family name", with: "Cole"
    click_button "Create person"
    assert_text "Jamie Cole"
    jamie_id = Party.find_by!(display_name: "Jamie Cole").id

    click_link "Back to directory"
    assert_current_path directory_parties_path
    click_link "Add to directory"
    assert_current_path new_directory_party_path
    click_link "Household"
    assert_field "Household name"
    fill_in "Household name", with: "Cole Household"
    click_button "Create household"
    assert_text "Cole Household"

    click_link "Back to directory"
    assert_current_path directory_parties_path
    click_link "Add to directory"
    assert_current_path new_directory_party_path
    click_link "Organization"
    assert_field "Legal name"
    fill_in "Legal name", with: "Summit Travel Co"
    fill_in "Trading name", with: "Summit Travel"
    click_button "Create organization"
    assert_text "Summit Travel"

    click_link "Directory"
    assert_text "Jamie Cole"
    assert_text "Cole Household"
    assert_text "Summit Travel"

    click_link "Jamie Cole"
    click_link "Edit"
    assert_field "Preferred name"
    fill_in "Preferred name", with: "Jim"
    click_button "Save changes"
    assert_text "Jim Cole"
    assert_equal jamie_id, Party.find_by!(display_name: "Jim Cole").id

    fill_in "Add alternate name", with: "James Cole"
    select "Former Name", from: "Add name kind"
    click_button "Add name"
    assert_text "Alternate name added."
    within("li.dd-list-item", text: "James Cole") do
      assert_css "strong.dd-list-title", text: "James Cole"
      assert_field "Alternate name", with: "James Cole"
    end
    assert_text "Jim Cole"

    click_link "Administration"
    assert_current_path administration_agency_path
    click_link "Team"
    assert_current_path administration_team_members_path
    click_link "Invite someone"
    assert_current_path new_administration_invitation_path
    fill_in "Email address", with: "alex.team@example.com"
    choose "Invite an existing person"
    select "Alex Morgan", from: "Existing person"
    check "Sunrise Travel (MAIN)"
    select "Sunrise Travel (MAIN)", from: "Default office"
    click_button "Send invitation"
    assert_text MembershipCommand::ELIGIBLE_INVITE_NOTICE

    alex_membership = AgencyMembership.joins(:user).find_by!(users: { email_address: "alex.team@example.com" })
    assert_equal people(:unlinked).party_id, alex_membership.person_party_id

    click_link "Team"
    assert_text "Alex Morgan"
    assert_text "alex.team@example.com"

    click_link "Invite someone"
    choose "Invite an existing person"
    assert_no_selector "option", text: "Jordan Blake"
    assert_no_selector "option", text: "Alex Morgan"

    fill_in "Email address", with: "new.person@example.com"
    choose "Create and invite a new person"
    fill_in "First name", with: "Riley"
    fill_in "Last name", with: "Chen"
    check "Sunrise Travel (MAIN)"
    select "Sunrise Travel (MAIN)", from: "Default office"
    click_button "Send invitation"
    assert_text MembershipCommand::ELIGIBLE_INVITE_NOTICE

    party_count = Party.where(agency: agencies(:one)).count
    visit edit_invitation_acceptance_path(alex_membership.invitation_token)
    fill_in "Password", with: "Newpass123!"
    fill_in "Password confirmation", with: "Newpass123!"
    click_button "Join DepartureDesk"
    assert_text "Dashboard"
    assert_equal party_count, Party.where(agency: agencies(:one)).count
    assert_equal people(:unlinked).party_id, alex_membership.reload.person_party_id
  end
end
