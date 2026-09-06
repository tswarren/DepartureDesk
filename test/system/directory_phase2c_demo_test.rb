require "application_system_test_case"

class DirectoryPhase2cDemoTest < ApplicationSystemTestCase
  test "organization can be client and supplier without duplicating contact identity" do
    sign_in_from_browser users(:one)
    organization = parties(:organization_one)
    contact = parties(:maria)
    independent = parties(:unlinked)
    organization_id = organization.id
    contact_id = contact.id
    independent_id = independent.id

    open_directory_party "Horizon Tours"
    select "Sunrise Travel (MAIN)", from: "Client responsible office"
    click_button "Add client role"
    assert_text "Client role added."
    select "Riley Staff", from: "Primary advisor"
    click_button "Assign advisor"
    assert_text "Client advisor updated."

    select "Sunrise Travel (MAIN)", from: "Supplier responsible office"
    click_button "Add supplier role"
    assert_text "Supplier role added."
    select "Cruise", from: "Service category"
    click_button "Add category"
    assert_text "Supplier category added."
    fill_in "Booking instructions", with: "Hold space 45 days out."
    click_button "Save supplier details"
    assert_text "Supplier role updated."

    within("nav[aria-label=Party]") { click_link "Relationships" }
    click_link "Add relationship"
    select "Organization Contact", from: "Relationship kind"
    select "Maria Ruiz (Person)", from: "Related party"
    click_button "Add relationship"
    assert_text "Maria Ruiz is a contact for Horizon Tours."
    click_link "Assign purpose"
    select "Booking", from: "Organization purpose"
    fill_in "Purpose priority", with: "1"
    click_button "Assign purpose"
    assert_text "Booking primary"

    open_directory_party "Maria Ruiz"
    assert_text "Not assigned"
    assert_no_text "Deactivate supplier role"
    assert_nil contact.reload.supplier_profile

    open_directory_party "Alex Morgan"
    select "Sunrise Travel (MAIN)", from: "Supplier responsible office"
    click_button "Add supplier role"
    assert_text "Supplier role added."

    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office

    open_directory_party "Horizon Tours"
    fill_in "Supplier deactivation reason", with: "Season over"
    accept_confirm { click_button "Deactivate supplier role" }
    assert_text "Supplier role deactivated."
    assert organization.reload.client_profile.active?
    assert organization.supplier_profile.inactive?
    assert organization.active?

    ChangeOfficeStatus.new(
      agency: agencies(:one),
      actor: users(:one),
      office: extra,
      to: "inactive",
      reason: "Seasonal"
    ).call
    error = assert_raises(MembershipCommand::Error) do
      ReactivateSupplierProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party: organization,
        profile: organization.supplier_profile,
        office: extra
      ).call
    end
    assert_equal :invalid, error.code

    open_directory_party "Horizon Tours"
    select "Sunrise Travel (MAIN)", from: "Supplier responsible office"
    click_button "Reactivate supplier role"
    assert_text "Supplier role reactivated."
    assert organization.supplier_profile.reload.active?
    assert_equal organization_id, organization.reload.id
    assert_equal contact_id, contact.reload.id
    assert_equal independent_id, independent.reload.id
    assert independent.supplier_profile.active?
    assert_nil contact.supplier_profile
  end
end
