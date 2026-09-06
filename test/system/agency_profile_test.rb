require "application_system_test_case"

class AgencyProfileTest < ApplicationSystemTestCase
  test "administrator edits the agency profile and sees the new name" do
    sign_in_from_browser users(:one)
    open_administration
    click_link_and_expect "Edit profile", heading: "Edit agency profile"
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
    sign_in_from_browser users(:two)

    assert_text agencies(:two).name
    assert_no_text "Administration"

    visit administration_agency_path
    assert_selector "h1.dd-page-title", text: "Dashboard"
    assert_text "You are not authorized to do that."
  end

  test "skip link remains available and administration fields stay labeled" do
    sign_in_from_browser users(:one)

    open_administration
    assert_text "Agency profile"
    assert_selector "a[href='#main-content']", text: "Skip to main content", visible: :all
    page.execute_script("document.querySelector(\"a[href='#main-content']\").focus()")
    assert_selector "a[href='#main-content']", text: "Skip to main content"
    assert_selector "nav[aria-label=Administration]"
    click_link_and_expect "Edit profile", heading: "Edit agency profile"
    assert_field "Display name"
    assert_field "Default currency"
  end
end
