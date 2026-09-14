require "application_system_test_case"

class ClientsDirectoryTest < ApplicationSystemTestCase
  test "an administrator creates an individual client" do
    sign_in_from_browser(agency_users(:harbor_admin))

    click_link "Clients"
    click_link "New Client"
    fill_in "First name", with: "Grace"
    fill_in "Last name", with: "Hopper"
    click_button "Create Client"

    assert_text "Client created."
    assert_text "CL-000001"
    assert_no_text "Organization"
  end
end
