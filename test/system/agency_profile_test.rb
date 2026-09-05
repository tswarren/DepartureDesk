require "application_system_test_case"

class AgencyProfileTest < ApplicationSystemTestCase
  test "administrator edits the agency profile and sees the new name" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    click_link "Administration"
    click_link "Edit profile"
    fill_in "Display name", with: "Sunrise Travel Group"
    fill_in "Legal name", with: "Sunrise Travel LLC"
    select "Canada (CA)", from: "Country"
    select "America/Toronto", from: "Default timezone"
    fill_in "Default currency", with: "CAD"
    click_button "Save profile"

    assert_text "Sunrise Travel Group"
    assert_text "Sunrise Travel LLC"
  end

  test "staff cannot discover administration in navigation" do
    visit new_session_path
    fill_in "Email address", with: users(:two).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_no_text "Administration"
    visit administration_agency_path
    assert_current_path root_path
    assert_text "You are not authorized to do that."
  end
end
