require "application_system_test_case"

class DirectoryRelationshipFoundationTest < ApplicationSystemTestCase
  test "overlapping households organization contact and ending an affiliation" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    click_link "Directory"
    click_link "Alex Morgan"
    click_link "Relationships"
    click_link "Add relationship"
    select "Household Member", from: "Relationship kind"
    select "Morgan Household (Household)", from: "Related party"
    click_button "Add relationship"
    assert_text "Alex Morgan is a member of Morgan Household."

    click_link "Add relationship"
    select "Household Member", from: "Relationship kind"
    select "Cole Household (Household)", from: "Related party"
    click_button "Add relationship"
    assert_text "Alex Morgan is a member of Cole Household."

    click_link "Directory"
    click_link "Maria Ruiz"
    click_link "Relationships"
    click_link "Add relationship"
    select "Organization Contact", from: "Relationship kind"
    select "Horizon Tours (Organization)", from: "Related party"
    click_button "Add relationship"
    assert_text "Maria Ruiz is a contact for Horizon Tours."

    click_link "Assign purpose"
    select "Booking", from: "Organization purpose"
    fill_in "Purpose priority", with: "1"
    click_button "Assign purpose"
    assert_text "Booking primary"

    within("li.dd-list-item", text: "Maria Ruiz is a contact for Horizon Tours.") do
      fill_in "Inclusive end date", with: Date.new(2026, 9, 30)
      fill_in "Ending reason", with: "Contract ended"
      click_button "End relationship"
    end
    assert_text "Relationship ended."
  end
end
