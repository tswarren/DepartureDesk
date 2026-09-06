require "application_system_test_case"

class DirectoryRoleProfilesTest < ApplicationSystemTestCase
  test "party overview assigns deactivates and reactivates roles" do
    sign_in_from_browser users(:one)
    open_directory_party "Horizon Tours"
    assert_text "Roles"
    assert_text "Not assigned"
    select "Sunrise Travel (MAIN)", from: "Client responsible office"
    click_button "Add client role"
    assert_text "Client role added."
    assert_text "Active"
    assert_text "Sunrise Travel (MAIN)"

    fill_in "Client deactivation reason", with: "Season over"
    accept_confirm { click_button "Deactivate client role" }
    assert_text "Client role deactivated."
    assert_text "Inactive"

    select "Sunrise Travel (MAIN)", from: "Client responsible office"
    click_button "Reactivate client role"
    assert_text "Client role reactivated."
    assert_text "Active"

    open_directory_party "Morgan Household"
    assert_text "Ineligible"
    assert_no_text "Add supplier role"
  end
end
