require "application_system_test_case"

class DirectoryPhase2dDemoTest < ApplicationSystemTestCase
  test "search duplicate warnings and unused-party lifecycle" do
    create_email_contact!(parties(:unlinked), address: "alex.search@example.com", actor: users(:one))
    create_phone_contact!(parties(:unlinked), number: "415-555-0199", actor: users(:one))
    parties(:unlinked).alternate_names.create!(
      agency: agencies(:one),
      name: "Alexander Morgan",
      name_kind: "former_name"
    )
    people(:unlinked).update!(date_of_birth: Date.new(1990, 5, 1))

    sign_in_from_browser users(:one)
    open_directory
    fill_in "Search", with: "Alexander"
    click_button "Apply filter"
    assert_text "Alex Morgan"

    fill_in "Search", with: "alex.search@example.com"
    click_button "Apply filter"
    assert_text "Alex Morgan"

    fill_in "Search", with: "415-555-0199"
    click_button "Apply filter"
    assert_text "Alex Morgan"

    click_link_and_expect "Add to directory", heading: "Add to directory"
    click_link "Person"
    assert_field "Given name"
    wait_for_turbo
    fill_in "Given name", with: "Alex"
    fill_in "Family name", with: "Morgan"
    click_button "Create person"
    assert_text "Possible existing records"
    assert_text "A similar directory record already exists."
    assert_no_text "Restricted credit discussion for administrators only."
    click_link "Use this record"
    assert_selector "h1.dd-page-title", exact_text: "Alex Morgan"
    add_party_role "client", office_label: "Sunrise Travel (MAIN)"
    assert_text "Active"

    open_directory
    click_link_and_expect "Add to directory", heading: "Add to directory"
    click_link "Person"
    assert_field "Given name"
    wait_for_turbo
    fill_in "Given name", with: "Alex"
    fill_in "Family name", with: "Morgan"
    fill_in_html_date "Date of birth", "1990-05-01"
    click_button "Create person"
    assert_text "A likely duplicate already exists."
    fill_in "Reason for creating a separate identity", with: "Twins with the same name"
    click_button "Create as a separate identity"
    assert_selector "h1.dd-page-title", exact_text: "Alex Morgan"
    duplicate = Party.where(agency: agencies(:one), display_name: "Alex Morgan").where.not(id: parties(:unlinked).id).order(:created_at).last

    click_party_tab "Record"
    fill_in "Party deactivation reason", with: "Unused duplicate"
    accept_confirm { click_button "Deactivate party" }
    assert_text "Party deactivated."
    assert duplicate.reload.deactivated?

    open_directory_party "Horizon Tours"
    add_party_role "supplier", office_label: "Sunrise Travel (MAIN)"
    click_party_tab "Record"
    fill_in "Party deactivation reason", with: "Still a supplier"
    accept_confirm { click_button "Deactivate party" }
    assert_text "Horizon Tours (supplier)"
    assert parties(:organization_one).reload.active?

    click_party_tab "Roles"
    fill_in "Supplier deactivation reason", with: "Season over"
    accept_confirm { click_button "Deactivate supplier role" }
    assert_text "Supplier role deactivated."
    assert parties(:organization_one).reload.active?

    open_directory
    assert_selector "a", exact_text: "Alex Morgan", count: 1
    check "Include inactive"
    click_button "Apply filter"
    assert_selector "a", exact_text: "Alex Morgan", count: 2
    visit directory_party_path(duplicate)
    assert_selector "h1.dd-page-title", exact_text: "Alex Morgan"
    click_party_tab "Record"
    fill_in "Party reactivation reason", with: "Needed again"
    click_button "Reactivate party"
    assert_text "Party reactivated."
    click_party_tab "Overview"
    assert_text "Not assigned"
    assert_nil duplicate.reload.client_profile
  end
end
