require "application_system_test_case"

class DirectoryContactFoundationTest < ApplicationSystemTestCase
  test "personal contacts household mailing address purposes and suppression" do
    visit new_session_path
    fill_in "Email address", with: users(:one).email_address
    fill_in "Password", with: "password"
    click_button "Sign in"
    assert_current_path root_path

    click_link "Directory"
    assert_current_path directory_parties_path
    click_link "Alex Morgan"
    assert_current_path directory_party_path(parties(:unlinked))
    within("nav[aria-label=Party]") { click_link "Contact information" }
    assert_current_path directory_party_contact_information_path(parties(:unlinked))
    assert_link "Add email"

    click_link "Add email"
    fill_in "Email address", with: "alex.personal@example.com"
    select "Personal", from: "Email type"
    click_button "Add email"
    assert_text "alex.personal@example.com"

    click_link "Add phone"
    fill_in "Phone number", with: "617-555-0142"
    select "Mobile", from: "Phone type"
    click_button "Add phone"
    assert_text "617-555-0142"

    click_link "Add email"
    fill_in "Email address", with: "alex.billing@example.com"
    select "Accounting", from: "Email type"
    click_button "Add email"
    assert_text "alex.billing@example.com"

    within("li.dd-list-item", text: "alex.personal@example.com") do
      select "General", from: "Set as primary purpose"
      click_button "Set as primary"
    end
    assert_text "Primary contact updated."

    within("li.dd-list-item", text: "alex.billing@example.com") do
      select "Billing", from: "Set as primary purpose"
      click_button "Set as primary"
    end
    assert_text "Primary contact updated."

    within("li.dd-list-item", text: "alex.personal@example.com") do
      fill_in "Do not use reason", with: "Mailbox not monitored"
      click_button "Mark do not use"
    end
    assert_text "Do not use"

    click_link "Directory"
    assert_current_path directory_parties_path
    click_link "Morgan Household"
    assert_current_path directory_party_path(parties(:household_one))
    within("nav[aria-label=Party]") { click_link "Contact information" }
    assert_current_path directory_party_contact_information_path(parties(:household_one))
    click_link "Add postal address"
    fill_in "Address line 1", with: "18 Harbor Street"
    fill_in "City or locality", with: "Boston"
    fill_in "Postal code", with: "02110"
    select "United States", from: "Country"
    fill_in "Address label", with: "Mailing"
    click_button "Add postal address"
    assert_text "18 Harbor Street"

    click_link "Directory"
    assert_current_path directory_parties_path
    click_link "Alex Morgan"
    assert_current_path directory_party_path(parties(:unlinked))
    within("nav[aria-label=Party]") { click_link "Contact information" }
    assert_current_path directory_party_contact_information_path(parties(:unlinked))
    assert_no_text "18 Harbor Street"
    assert_text "alex.personal@example.com"
    assert_text "Do not use"
  end
end
