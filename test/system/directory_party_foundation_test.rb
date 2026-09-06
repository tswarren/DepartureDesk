require "application_system_test_case"

class DirectoryPartyFoundationTest < ApplicationSystemTestCase
  test "directory create edit alternate names and existing-person invitation" do
    sign_in_from_browser users(:one)
    open_directory
    assert_text "Alex Morgan"
    assert_text "Morgan Household"
    assert_text "Horizon Tours"

    click_link_and_expect "Add to directory", heading: "Add to directory"
    assert_text "Choose a kind. Party kind cannot be changed later."
    click_link "Person"
    assert_field "Given name"
    wait_for_turbo
    fill_in "Given name", with: "Jamie"
    fill_in "Family name", with: "Cole"
    click_button "Create person"
    assert_text "Jamie Cole"
    jamie_id = Party.find_by!(display_name: "Jamie Cole").id

    click_link_and_expect "Back to directory", heading: "People, households, and organizations"
    click_link_and_expect "Add to directory", heading: "Add to directory"
    click_link "Household"
    assert_field "Household name"
    wait_for_turbo
    fill_in "Household name", with: "Cole Household"
    click_button "Create household"
    assert_text "Cole Household"

    click_link_and_expect "Back to directory", heading: "People, households, and organizations"
    click_link_and_expect "Add to directory", heading: "Add to directory"
    click_link "Organization"
    assert_field "Legal name"
    wait_for_turbo
    fill_in "Legal name", with: "Summit Travel Co"
    fill_in "Trading name", with: "Summit Travel"
    click_button "Create organization"
    assert_text "Summit Travel"

    open_directory
    assert_text "Jamie Cole"
    assert_text "Cole Household"
    assert_text "Summit Travel"

    within("table.dd-table") { click_link "Jamie Cole", exact: true }
    assert_selector "h1.dd-page-title", text: "Jamie Cole"
    wait_for_turbo
    click_link_and_expect "Edit", heading: "Edit Jamie Cole"
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

    open_administration
    click_link_and_expect "Team", heading: "Team"
    click_link_and_expect "Invite someone", heading: "Invite someone"
    fill_in "Email address", with: "alex.team@example.com"
    choose "Invite an existing person"
    select "Alex Morgan", from: "Existing person"
    check "Sunrise Travel (MAIN)"
    select "Sunrise Travel (MAIN)", from: "Default office"
    click_button "Send invitation"
    assert_text MembershipCommand::ELIGIBLE_INVITE_NOTICE

    alex_membership = AgencyMembership.joins(:user).find_by!(users: { email_address: "alex.team@example.com" })
    assert_equal people(:unlinked).party_id, alex_membership.person_party_id

    click_link_and_expect "Team", heading: "Team"
    assert_text "Alex Morgan"
    assert_text "alex.team@example.com"

    click_link_and_expect "Invite someone", heading: "Invite someone"
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
