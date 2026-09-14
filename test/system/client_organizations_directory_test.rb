require "application_system_test_case"

class ClientOrganizationsDirectoryTest < ApplicationSystemTestCase
  test "an administrator creates an organization client with website and contact" do
    sign_in_from_browser(agency_users(:harbor_admin))

    click_link "Clients"
    click_link "New Client"
    click_link "Organization"
    fill_in "Display name", with: "Harbor Group Travel"
    click_button "Create Client"

    assert_text "Client created."
    assert_text "CL-000001"
    assert_text "Harbor Group Travel"

    within(:xpath, "//article[.//h2[normalize-space()='Websites']]") do
      click_link "Add"
    end
    fill_in "Website", with: "example.com"
    click_button "Save website"

    assert_text "Website saved."
    assert_text "example.com"

    within(:xpath, "//article[.//h2[normalize-space()='Current contacts']]") do
      click_link "Add"
    end
    fill_in "First name", with: "Pat"
    fill_in "Last name", with: "Contact"
    check "Primary contact"
    click_button "Save contact"

    assert_text "Organization contact saved."
    assert_text "Pat Contact"
    assert_text "Primary"
  end
end
