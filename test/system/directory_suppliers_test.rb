require "application_system_test_case"

class DirectorySuppliersTest < ApplicationSystemTestCase
  test "supplier directory lists an organization supplier and not its contact" do
    sign_in_from_browser users(:one)
    open_directory_party "Horizon Tours"
    select "Sunrise Travel (MAIN)", from: "Supplier responsible office"
    click_button "Add supplier role"
    assert_text "Supplier role added."
    select "Cruise", from: "Service category"
    click_button "Add category"
    assert_text "Supplier category added."

    click_link_and_expect "Suppliers", heading: "Suppliers"
    assert_text "Horizon Tours"
    assert_text "Cruise"
    assert_no_text "Maria Ruiz"
  end
end
