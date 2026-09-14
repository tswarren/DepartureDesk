require "test_helper"

class ClientsDirectoryTest < ActionDispatch::IntegrationTest
  setup do
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @staff = agency_users(:harbor_staff)
  end

  test "an administrator creates a person and client and a viewer cannot" do
    sign_in_as @viewer
    assert_no_difference -> { Client.count } do
      post clients_path, params: { client_person: { first_name: "Viewer", last_name: "Blocked" } }
    end
    assert_redirected_to root_path

    sign_in_as @admin
    post clients_path, params: { client_person: { first_name: "Ada", last_name: "Lovelace" } }
    person = agencies(:harbor).client_people.find_by!(last_name: "Lovelace")
    assert_redirected_to client_person_path(person)
    follow_redirect!
    assert_match "CL-000001", response.body
    assert_select "dl.dd-definition-list"
    assert_select "table.dd-table--channels", 3
  end

  test "a viewer profile omits contact destinations" do
    person = CreateClientPerson.new(agency: agencies(:harbor), actor: @admin, names: { first_name: "Shown", last_name: "Name" }).call.record
    CreateClientPersonEmailAddress.new(agency: agencies(:harbor), actor: @admin, client_person: person, attributes: { address: "secret@example.com" }).call

    sign_in_as @viewer
    get client_person_path(person)
    assert_response :success
    assert_match "Shown", response.body
    assert_no_match "secret@example.com", response.body
  end

  test "another agency's person is not found" do
    person = CreateClientPerson.new(agency: agencies(:cove), actor: agency_users(:cove_admin), names: { first_name: "Cove", last_name: "Person" }).call.record

    sign_in_as @staff
    get client_person_path(person)
    assert_response :not_found
  end

  test "a new phone number defaults the country list to the agency" do
    person = CreateClientPerson.new(agency: agencies(:harbor), actor: @admin, names: { first_name: "Dial", last_name: "Tone" }).call.record

    sign_in_as @admin
    get new_client_person_phone_number_path(person)

    assert_response :success
    assert_select "select[name='client_person_phone_number[country_code]'] option[selected][value=?]", agencies(:harbor).country_code
  end

  test "set primary is a row action and status confirmation is on the edit page" do
    person = CreateClientPerson.new(agency: agencies(:harbor), actor: @admin, names: { first_name: "Primary", last_name: "Row" }).call.record
    email = CreateClientPersonEmailAddress.new(
      agency: agencies(:harbor), actor: @admin, client_person: person, attributes: { address: "row@example.com" }
    ).call.record

    sign_in_as @admin
    get client_person_path(person)
    assert_select "button", text: "Set primary"
    assert_select "input[name=lock_version][value=?]", email.lock_version.to_s
    assert_select "a", text: "Change status", count: 0

    post set_primary_client_person_email_address_path(person, email), params: { lock_version: email.lock_version }
    assert_redirected_to client_person_path(person)
    assert email.reload.preferred?

    get edit_client_person_email_address_path(person, email)
    assert_select "a", text: "Change status"
  end

  test "status can be filtered without a search and reset clears it" do
    CreateClientPerson.new(agency: agencies(:harbor), actor: @admin, names: { first_name: "Still", last_name: "Active" }).call
    inactive = CreateClientPerson.new(agency: agencies(:harbor), actor: @admin, names: { first_name: "Gone", last_name: "Quiet" }).call.record
    ChangeClientPersonStatus.new(agency: agencies(:harbor), actor: @admin, client_person: inactive, status: "inactive", lock_version: inactive.lock_version).call

    sign_in_as @admin
    get clients_path, params: { status: "inactive", q: "" }

    assert_response :success
    assert_match "Gone", response.body
    assert_no_match "Still", response.body
    assert_select "a[href=?]", clients_path, text: "Reset"
  end

  test "duplicate review renders a token and does not save until acknowledged" do
    CreateIndividualClient.new(agency: agencies(:harbor), actor: @admin, names: { first_name: "Ada", last_name: "Lovelace" }).call
    sign_in_as @admin

    post clients_path, params: { client_person: { first_name: "Ada", last_name: "Lovelace" } }
    assert_response :unprocessable_entity
    assert_select "input[name=acknowledgement_token]"
    assert_select "a", text: "View existing"
    assert_equal 1, agencies(:harbor).clients.count
  end
end
