require "test_helper"

class ClientOrganizationsDirectoryTest < ActionDispatch::IntegrationTest
  setup do
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @agency = agencies(:harbor)
  end

  test "POST clients with organization creates a Client and organizations create does not" do
    sign_in_as @admin

    assert_difference -> { @agency.clients.count }, 1 do
      post clients_path, params: {
        source: "organization",
        client_organization: { display_name: "Atomic Org Client" }
      }
    end
    organization = @agency.client_organizations.find_by!(display_name: "Atomic Org Client")
    assert_redirected_to client_organization_path(organization)
    assert organization.client.present?

    assert_no_difference -> { @agency.clients.count } do
      post client_organizations_path, params: { client_organization: { display_name: "Org Only" } }
    end
    org_only = @agency.client_organizations.find_by!(display_name: "Org Only")
    assert_nil org_only.client
    assert_redirected_to client_organization_path(org_only)
  end

  test "organization contact points expose set primary like people contacts" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Preferred Org" }).call.record
    email = CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "row@example.com" }
    ).call.record

    sign_in_as @admin
    get client_organization_path(organization)
    assert_select "button", text: "Set primary"

    post set_primary_client_organization_email_address_path(organization, email), params: { lock_version: email.lock_version }
    assert_redirected_to client_organization_path(organization)
    assert email.reload.preferred?
  end

  test "new organization contact form omits start and end dates and defaults start to today" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Dated Org" }).call.record
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Today", last_name: "Contact" }).call.record
    today = Time.current.in_time_zone(@agency.default_timezone).to_date

    sign_in_as @admin
    get new_client_organization_contact_path(organization)
    assert_response :success
    assert_select "input[name='client_organization_contact[starts_on]']", count: 0
    assert_select "input[name='client_organization_contact[ends_on]']", count: 0

    post client_organization_contacts_path(organization), params: {
      client_organization_contact: { client_person_id: person.id, primary: true },
      client_person: { first_name: "", last_name: "" }
    }
    assignment = organization.organization_contacts.current.first
    assert_redirected_to client_organization_path(organization)
    assert_equal today, assignment.starts_on
    assert_nil assignment.ends_on
  end

  test "linking an existing person as organization contact does not require new person fields" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Contact Org" }).call.record
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Existing", last_name: "Person" }).call.record

    sign_in_as @admin
    get new_client_organization_contact_path(organization)
    assert_response :success
    assert_select "input[name='client_person[first_name]']:not([required])"
    assert_select "input[name='client_person[last_name]']:not([required])"

    assert_difference -> { organization.organization_contacts.count }, 1 do
      post client_organization_contacts_path(organization), params: {
        client_organization_contact: {
          client_person_id: person.id,
          primary: true
        },
        client_person: { first_name: "", last_name: "" }
      }
    end
    assert_redirected_to client_organization_path(organization)
    assert_equal person.id, organization.organization_contacts.current.first.client_person_id
    assert_equal 1, @agency.client_people.where(first_name: "Existing", last_name: "Person").count
  end

  test "viewer sees organization identity and assignment people but not destinations" do
    organization = CreateClientOrganization.new(agency: @agency, actor: @admin, names: { display_name: "Visible Org" }).call.record
    CreateClientOrganizationEmailAddress.new(
      agency: @agency, actor: @admin, client_organization: organization, attributes: { address: "hidden-org@example.com" }
    ).call
    person = CreateClientPerson.new(agency: @agency, actor: @admin, names: { first_name: "Named", last_name: "Contact" }).call.record
    AddClientOrganizationContact.new(
      agency: @agency,
      actor: @admin,
      client_organization: organization,
      client_person: person,
      attributes: { starts_on: Date.new(2026, 1, 1), primary: true }
    ).call

    sign_in_as @viewer
    get client_organization_path(organization)
    assert_response :success
    assert_match "Visible Org", response.body
    assert_match "Named Contact", response.body
    assert_no_match "hidden-org@example.com", response.body
  end

  test "another agency organization is not found" do
    organization = CreateClientOrganization.new(
      agency: agencies(:cove),
      actor: agency_users(:cove_admin),
      names: { display_name: "Cove Org" }
    ).call.record

    sign_in_as @admin
    get client_organization_path(organization)
    assert_response :not_found
  end

  test "directory browse without q uses the shared count message" do
    sign_in_as @admin
    get clients_path

    assert_response :success
    assert_match(/0 (match|record)/, response.body)
    assert_select "select[name=kind] option[selected][value=all]"
  end
end
