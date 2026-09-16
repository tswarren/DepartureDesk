require "application_system_test_case"

class M1DirectoryAcceptanceTest < ApplicationSystemTestCase
  test "keyboard workflows create clients, organization contacts, and supplier records" do
    scenario = M1DirectoryScenario.celebrity
    sign_in_from_browser(scenario.actor, password: M1DirectoryScenario::PASSWORD)

    activate "Clients"
    activate "New Client"
    find_field("First name").send_keys("Keyboard")
    find_field("Last name").send_keys("Client")
    find_button("Create Client").send_keys(:return)
    wait_for_turbo
    assert_text "Client created."

    activate "Clients"
    activate "New Client"
    activate "Organization"
    find_field("Display name").send_keys("Keyboard Foods")
    find_button("Create Client").send_keys(:return)
    wait_for_turbo
    assert_text "Client created."

    within(:xpath, "//article[.//h2[normalize-space()='Current contacts']]") do
      find(:link, "Add").send_keys(:return)
    end
    wait_for_turbo
    find_field("First name").send_keys("Pat")
    find_field("Last name").send_keys("Coordinator")
    find_button("Save contact").send_keys(:return)
    wait_for_turbo
    assert_text "Organization contact saved."
    find(:link, "End").send_keys(:return)
    wait_for_turbo
    find_button("End contact").send_keys(:return)
    wait_for_turbo
    assert_text "Organization contact ended."

    activate "Suppliers"
    activate "New Supplier"
    find_field("Display name").send_keys("Celebrity Cruises")
    check "Cruise line"
    find_button("Save supplier").send_keys(:return)
    wait_for_turbo
    assert_text "Possible duplicates"
    select "Confirmed distinct", from: "Why these are not the same record"
    find_button("Save supplier").send_keys(:return)
    wait_for_turbo
    assert_text "Supplier saved."
    supplier = scenario.agency.suppliers.order(:created_at).last

    within(:xpath, "//article[.//h2[normalize-space()='Locations']]") do
      find(:link, "Add").send_keys(:return)
    end
    wait_for_turbo
    find_field("Name").send_keys("Keyboard Terminal")
    find_button("Save location").send_keys(:return)
    wait_for_turbo
    assert_text "Location saved."

    visit supplier_path(supplier)
    within(:xpath, "//article[.//h2[normalize-space()='Contacts']]") do
      find(:link, "Add").send_keys(:return)
    end
    wait_for_turbo
    find_field("First name").send_keys("Kay")
    find_field("Last name").send_keys("Contact")
    find_button("Save contact").send_keys(:return)
    wait_for_turbo
    assert_text "Contact saved."

    within(:xpath, "//article[.//h2[normalize-space()='Email addresses']]") do
      find(:link, "Add").send_keys(:return)
    end
    wait_for_turbo
    find_field("Email address").send_keys("kay-#{scenario.suffix}@example.test")
    find_button("Save email address").send_keys(:return)
    wait_for_turbo
    assert_text "Email address saved."
    find_button("Set primary").send_keys(:return)
    wait_for_turbo
    assert_text "Email address set as primary."
    find_button("Set preferred").send_keys(:return)
    wait_for_turbo
    assert_text "Preferred contact updated."

    visit supplier_path(supplier)
    find(:link, "Change status").send_keys(:return)
    wait_for_turbo
    assert_text "Inactivation impact"
    select "Inactive", from: "Status"
    find_button("Update status").send_keys(:return)
    wait_for_turbo
    assert_text "Supplier status updated."
    assert_text "Inactive"
  end

  test "empty filtered truncation validation duplicate viewer and not-found states" do
    blank = M1DirectoryScenario.empty
    celebrity = M1DirectoryScenario.celebrity
    agency = blank.agency
    actor = blank.actor

    sign_in_from_browser(actor, password: M1DirectoryScenario::PASSWORD)
    visit clients_path
    assert_text "0 records matched"

    fill_in "Search", with: "Nobodyhere"
    click_button "Apply"
    assert_text "0 records matched"

    51.times do |index|
      CreateClientPerson.new(agency:, actor:, names: { first_name: "Truncsys", last_name: format("P%03d", index) }).call
    end
    visit clients_path
    fill_in "Search", with: "Truncsys"
    click_button "Apply"
    assert_text "Showing the first 50 records matched"

    supplier = CreateSupplier.new(
      agency:, actor:, kind: "organization",
      names: { display_name: "Validation Host" },
      categories: [ "cruise_line" ]
    ).call.record
    visit new_supplier_website_path(supplier)
    fill_in "Website", with: "not a website"
    fill_in "Label", with: "Kept label"
    click_button "Save website"
    wait_for_turbo
    assert_selector "#form-error-summary"
    assert_text "Please fix the following:"
    assert_selector "#form-error-summary:focus"
    assert_field "Label", with: "Kept label"
    assert_field "Website", with: "not a website"
    within("#form-error-summary") { find("a").click }
    assert_equal "supplier_website_url", page.evaluate_script("document.activeElement && document.activeElement.id")

    CreateSupplier.new(agency:, actor:, kind: "organization", names: { display_name: "Dup State Line" }, categories: [ "cruise_line" ]).call
    visit new_supplier_path
    fill_in "Display name", with: "Dup State Line"
    check "Cruise line"
    click_button "Save supplier"
    assert_text "Possible duplicates"
    page.execute_script("document.querySelector('input[name=acknowledgement_token]').value = 'expired-token'")
    select "Confirmed distinct", from: "Why these are not the same record"
    click_button "Save supplier"
    assert_text "Possible duplicates"

    click_button "Sign out"
    wait_for_turbo
    sign_in_from_browser(celebrity.viewer, password: M1DirectoryScenario::PASSWORD)
    visit clients_path
    fill_in "Search", with: celebrity.martha_email.address
    click_button "Apply"
    assert_no_text "Martha"
    assert_no_text celebrity.martha_email.address
    visit client_person_path(celebrity.martha)
    assert_text "Martha"
    assert_no_text celebrity.martha_email.address
    visit new_client_path
    assert_current_path root_path

    visit client_person_path(ClientPerson.find_by!(agency_id: blank.agency.id))
    assert_text(/RecordNotFound|doesn't exist|Not Found/i)
  end
end
