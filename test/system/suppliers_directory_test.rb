require "application_system_test_case"

class SuppliersDirectoryTest < ApplicationSystemTestCase
  setup do
    agencies(:harbor).reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end

  test "an administrator creates a cruise line supplier with a website" do
    sign_in_from_browser(agency_users(:harbor_admin))

    open_suppliers
    click_link "New Supplier"
    assert_selector "h1.dd-page-title", exact_text: "New supplier"

    choose "Organization"
    fill_in "Display name", with: "Celebrity Cruises"
    check "Cruise line"
    click_button "Save supplier"

    assert_text "Supplier saved."
    assert_text "SUP-000001"
    assert_text "Celebrity Cruises"
    assert_text "Cruise line"

    within(:xpath, "//article[.//h2[normalize-space()='Websites']]") do
      click_link "Add"
    end
    fill_in "Website", with: "example.com"
    click_button "Save website"

    assert_text "Website saved."
    assert_text "example.com"
    assert_button "Set primary"

    click_button "Set primary"
    assert_text "Website set as primary."
    assert_text "Preferred"
  end
end
