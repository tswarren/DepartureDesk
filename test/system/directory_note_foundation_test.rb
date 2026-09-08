require "application_system_test_case"

class DirectoryNoteFoundationTest < ApplicationSystemTestCase
  test "standard note correction and administrator-only isolation" do
    sign_in_from_browser users(:one)
    open_directory_party "Alex Morgan"
    click_party_tab "Notes"
    wait_for_turbo
    click_link "Add note"
    wait_for_turbo
    assert_field "New note"
    fill_in "New note", with: "Likes aisle seats on the group air."
    click_button "Add note"
    assert_text "Likes aisle seats on the group air."

    within(".dd-note-item", text: "Likes aisle seats on the group air.") do
      click_link "Correct"
    end
    within(".dd-note-item", text: "Likes aisle seats on the group air.") do
      fill_in "Corrected note", with: "Prefers window seats on the group air."
      fill_in "Correction reason", with: "Updated preference"
      click_button "Correct note"
    end
    assert_text "Prefers window seats on the group air."
    click_link "History"
    wait_for_turbo
    assert_text "Likes aisle seats on the group air."
    assert_text "Superseded"
    click_link "Current"
    wait_for_turbo
    click_link "Add note"
    wait_for_turbo
    assert_field "New note"
    fill_in "New note", with: "Internal credit discussion."
    check "Administrator-only note"
    click_button "Add note"
    assert_text "Internal credit discussion."

    click_button "Sign out"
    wait_for_turbo
    sign_in_from_browser users(:staff_one)
    open_directory_party "Alex Morgan"
    click_party_tab "Notes"
    wait_for_turbo
    assert_link "Add note"
    assert_no_field "New note"
    assert_text "Prefers window seats on the group air."
    assert_no_text "Internal credit discussion."
    assert_no_text "Administrator only"
    assert_no_text "Admin only"
  end
end
