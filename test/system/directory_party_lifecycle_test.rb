require "application_system_test_case"

class DirectoryPartyLifecycleTest < ApplicationSystemTestCase
  test "unused party can be deactivated hidden and reactivated without restoring roles" do
    sign_in_from_browser users(:one)
    open_directory_party "Alex Morgan"
    click_link "Record"
    fill_in "Party deactivation reason", with: "Unused duplicate"
    accept_confirm { click_button "Deactivate party" }
    assert_text "Party deactivated."

    open_directory
    assert_no_text "Alex Morgan"
    check "Include inactive"
    click_button "Apply filter"
    assert_text "Alex Morgan"

    click_link "Alex Morgan"
    assert_selector "h1.dd-page-title", exact_text: "Alex Morgan"
    click_link "Record"
    fill_in "Party reactivation reason", with: "Needed again"
    click_button "Reactivate party"
    assert_text "Party reactivated."
    click_link "Overview"
    assert_text "Not assigned"
  end
end
