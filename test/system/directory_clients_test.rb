require "application_system_test_case"

class DirectoryClientsTest < ApplicationSystemTestCase
  test "client directory and advisor picker stay on the party identity" do
    sign_in_from_browser users(:one)
    open_directory_party "Horizon Tours"
    add_party_role "client", office_label: "Sunrise Travel (MAIN)"
    select "Riley Staff", from: "Primary advisor"
    click_button_and_expect "Assign advisor", text: "Client advisor updated."
    assert_text "Riley Staff"

    open_directory
    click_link_and_expect "Clients", heading: "Clients"
    assert_text "Horizon Tours"
    assert_text "Riley Staff"
    assert_text "No preference"
    click_link "Horizon Tours"
    assert_selector "h1.dd-page-title", exact_text: "Horizon Tours"
  end
end
