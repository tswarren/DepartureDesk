require "application_system_test_case"

class DirectoryPartyLifecycleTest < ApplicationSystemTestCase
  test "unused party can be deactivated hidden and reactivated without restoring roles" do
    sign_in_from_browser users(:one)
    open_directory_party "Alex Morgan"
    deactivate_party_from_record "Unused duplicate"
    assert_text "Party deactivated."

    open_directory
    assert_no_text "Alex Morgan"
    check "Include inactive"
    click_button "Apply filter"
    assert_text "Alex Morgan"

    click_link "Alex Morgan"
    assert_selector "h1.dd-page-title", exact_text: "Alex Morgan"
    reactivate_party_from_record "Needed again"
    assert_text "Party reactivated."
    click_party_tab "Overview"
    assert_text "Not assigned"
  end
end
