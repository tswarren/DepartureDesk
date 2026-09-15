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

  test "staff can create and edit a supplier" do
    sign_in_from_browser(agency_users(:harbor_staff))

    open_suppliers
    click_link "New Supplier"
    choose "Organization"
    fill_in "Display name", with: "Staff Lodging Co"
    check "Lodging"
    click_button "Save supplier"

    assert_text "Supplier saved."
    assert_text "Staff Lodging Co"
    click_link "Edit supplier"
    fill_in "Display name", with: "Staff Lodging Company"
    click_button "Save supplier"
    assert_text "Supplier updated."
    assert_text "Staff Lodging Company"
  end

  test "viewer can search suppliers but not see destinations" do
    agency = agencies(:harbor)
    admin = agency_users(:harbor_admin)
    supplier = CreateSupplier.new(
      agency: agency,
      actor: admin,
      kind: "organization",
      names: { display_name: "Viewer Harbor Hotel" },
      categories: [ "lodging" ]
    ).call.record
    CreateSupplierEmailAddress.new(
      agency: agency,
      actor: admin,
      supplier: supplier,
      attributes: { address: "viewer-hidden@example.com" }
    ).call

    sign_in_from_browser(agency_users(:harbor_viewer))
    open_suppliers
    fill_in "Search", with: "Viewer Harbor Hotel"
    click_button "Apply"

    assert_text "Viewer Harbor Hotel"
    click_link "Viewer Harbor Hotel"
    assert_text "Lodging"
    assert_no_text "viewer-hidden@example.com"
    assert_no_text "New Supplier"
  end

  test "duplicate review create-anyway and validation summary work in the browser" do
    agency = agencies(:harbor)
    admin = agency_users(:harbor_admin)
    CreateSupplier.new(
      agency: agency,
      actor: admin,
      kind: "organization",
      names: { display_name: "Duplicate Cruise Line" },
      categories: [ "cruise_line" ]
    ).call

    sign_in_from_browser(admin)
    open_suppliers
    click_link "New Supplier"
    choose "Organization"
    fill_in "Display name", with: "Duplicate Cruise Line"
    check "Cruise line"
    click_button "Save supplier"

    assert_text "Possible duplicates"
    select "Confirmed distinct", from: "Why these are not the same record"
    click_button "Save supplier"
    assert_text "Supplier saved."
    assert_text "Duplicate Cruise Line"

    click_link "Edit categories"
    uncheck "Cruise line"
    click_button "Save categories"
    assert_selector "#form-error-summary"
    assert_text "Choose at least one supplier category"
  end
end
