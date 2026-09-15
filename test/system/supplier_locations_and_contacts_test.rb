require "application_system_test_case"

class SupplierLocationsAndContactsSystemTest < ApplicationSystemTestCase
  setup do
    agencies(:harbor).reference_sequences.find_or_create_by!(namespace: ReferenceSequence::SUPPLIER_NAMESPACE) do |sequence|
      sequence.next_value = 1
    end
  end

  test "administrator creates a location with duplicate review and a preferred contact destination" do
    agency = agencies(:harbor)
    admin = agency_users(:harbor_admin)
    supplier = CreateSupplier.new(
      agency: agency,
      actor: admin,
      kind: "organization",
      names: { display_name: "Celebrity Cruises System" },
      categories: [ "cruise_line" ]
    ).call.record
    CreateSupplierLocation.new(
      agency: agency,
      actor: admin,
      supplier: supplier,
      attributes: {
        name: "Miami Terminal",
        address_line_1: "1 Cruise Blvd",
        address_locality: "Miami",
        address_postal_code: "33101",
        address_country_code: "US"
      }
    ).call

    sign_in_from_browser(admin)
    visit supplier_path(supplier)

    within(:xpath, "//article[.//h2[normalize-space()='Locations']]") do
      click_link "Add"
    end
    fill_in "Name", with: "Duplicate Terminal"
    fill_in "Address line 1", with: "1 Cruise Blvd"
    fill_in "Locality", with: "Miami"
    fill_in "Postal code", with: "33101"
    fill_in "supplier_location_address_country_code", with: "US"
    click_button "Save location"

    assert_text "Possible duplicates"
    select "Confirmed distinct", from: "Why these are not the same record"
    click_button "Save location"
    assert_text "Location saved."
    assert_text "Duplicate Terminal"

    visit supplier_path(supplier)
    within(:xpath, "//article[.//h2[normalize-space()='Contacts']]") do
      click_link "Add"
    end
    fill_in "First name", with: "Ada"
    fill_in "Last name", with: "Guide"
    click_button "Save contact"
    assert_text "Contact saved."

    within(:xpath, "//article[.//h2[normalize-space()='Email addresses']]") do
      click_link "Add"
    end
    fill_in "Email address", with: "ada.guide@example.com"
    click_button "Save email address"
    assert_text "Email address saved."
    assert_button "Set primary"
    click_button "Set primary"
    assert_text "Email address set as primary."
    assert_text "Primary"

    click_button "Set preferred"
    assert_text "Preferred contact updated."
  end

  test "viewer can find a location by name without seeing address phone or contacts" do
    agency = agencies(:harbor)
    admin = agency_users(:harbor_admin)
    supplier = CreateSupplier.new(
      agency: agency,
      actor: admin,
      kind: "organization",
      names: { display_name: "Viewer Location Host" },
      categories: [ "lodging" ]
    ).call.record
    CreateSupplierLocation.new(
      agency: agency,
      actor: admin,
      supplier: supplier,
      attributes: {
        name: "Hidden Port Desk",
        address_line_1: "99 Secret Way",
        address_country_code: "US",
        phone_number: "202-555-0199",
        phone_country_code: "US"
      }
    ).call
    CreateSupplierContact.new(
      agency: agency,
      actor: admin,
      supplier: supplier,
      attributes: { first_name: "Hidden", last_name: "Person" }
    ).call

    sign_in_from_browser(agency_users(:harbor_viewer))
    visit suppliers_path
    fill_in "Search", with: "Hidden Port Desk"
    click_button "Apply"

    assert_text "Hidden Port Desk"
    assert_text "Location · Viewer Location Host"
    click_link "Hidden Port Desk"
    assert_text "Hidden Port Desk"
    assert_no_text "99 Secret Way"
    assert_no_text "202-555-0199"
    assert_no_text "Hidden Person"
    assert_no_text "Contacts"
  end
end
