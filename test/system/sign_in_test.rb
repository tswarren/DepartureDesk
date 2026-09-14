require "application_system_test_case"

class SignInTest < ApplicationSystemTestCase
  test "an administrator signs in with a workspace code and sees administration" do
    sign_in_from_browser(agency_users(:harbor_admin))

    assert_text "Harbor Travel"
    assert_link "Administration"
    assert_no_link "Directory"
    assert_no_link "Departures"
    assert_no_text "Accounting"
  end

  test "staff can see the workspace and change office but not administer users" do
    sign_in_from_browser(agency_users(:harbor_staff))

    assert_text "Dashboard"
    assert_no_link "Administration"
    click_link "Change current office"
    choose "Harbor West (WEST)"
    click_button "Use this office"
    assert_text "Current office updated."
    assert_text "Harbor West (WEST)"
  end
end
