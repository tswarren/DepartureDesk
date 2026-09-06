require "application_system_test_case"

class DirectoryNoteFoundationTest < ApplicationSystemTestCase
  test "standard note correction and administrator-only isolation" do
    sign_in_from_browser users(:one)
    open_directory_party "Alex Morgan"
    within("nav[aria-label=Party]") { click_link "Notes" }
    assert_field "New note"
    wait_for_turbo
    fill_in "New note", with: "Likes aisle seats on the group air."
    click_button "Add note"
    assert_text "Likes aisle seats on the group air."

    within("li.dd-list-item", text: "Likes aisle seats on the group air.") do
      fill_in "Corrected note", with: "Prefers window seats on the group air."
      fill_in "Correction reason", with: "Updated preference"
      click_button "Correct note"
    end
    assert_text "Prefers window seats on the group air."
    assert_text "Likes aisle seats on the group air."
    assert_text "Superseded"

    fill_in "New note", with: "Internal credit discussion."
    select "Administrator only", from: "Note visibility"
    click_button "Add note"
    assert_text "Internal credit discussion."

    click_button "Sign out"
    sign_in_from_browser users(:staff_one)
    open_directory_party "Alex Morgan"
    within("nav[aria-label=Party]") { click_link "Notes" }
    assert_field "New note"
    wait_for_turbo
    assert_text "Prefers window seats on the group air."
    assert_no_text "Internal credit discussion."
    assert_no_text "Administrator only"
  end
end
