require "test_helper"

module Directory
  class ClientsControllerTest < ActionDispatch::IntegrationTest
    test "lists clients agency-wide and does not filter by current office" do
      sign_in_as(users(:one))
      assign_client_role!(parties(:unlinked), actor: users(:one), office: offices(:one))
      extra = CreateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        name: "Boston",
        code: "BOS",
        default_timezone: agencies(:one).default_timezone
      ).call.office
      patch current_office_path, params: { office_id: extra.id }
      assert_redirected_to root_url

      get directory_clients_path
      assert_response :success
      assert_includes response.body, parties(:unlinked).display_name
      assert_includes response.body, "Clients"
      assert_select "a[href=?]", directory_suppliers_path, text: "Suppliers"
      assert_select "nav[aria-label='Primary navigation'] a", text: "Clients", count: 0
    end

    test "directory index links to the client directory" do
      sign_in_as(users(:one))

      get directory_parties_path
      assert_response :success
      assert_select "a[href=?]", directory_clients_path, text: "Clients"
    end

    test "cross-agency office and advisor filters return not found" do
      sign_in_as(users(:one))

      get directory_clients_path, params: { office_id: offices(:two).id }
      assert_response :not_found

      get directory_clients_path, params: { advisor_id: agency_memberships(:two).id }
      assert_response :not_found
    end

    test "cross-agency parties are omitted" do
      sign_in_as(users(:one))
      assign_client_role!(parties(:unlinked), actor: users(:one))
      assign_client_role!(parties(:two), actor: users(:two), office: offices(:two))

      get directory_clients_path
      assert_response :success
      assert_includes response.body, parties(:unlinked).display_name
      assert_not_includes response.body, parties(:two).display_name
    end

    test "no_preference lists general primaries by kind and missing preferred kind is explicit" do
      sign_in_as(users(:one))
      party = parties(:unlinked)
      profile = assign_client_role!(party, actor: users(:one))
      phone = CreatePartyContactPoint.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_kind: "phone",
        attributes: { display_number: "415-555-0199", phone_type: "mobile", parsed_country_code: "US" }
      ).call.contact_point
      SetContactPointPrimary.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point: phone,
        purpose: "general"
      ).call

      get directory_clients_path
      assert_response :success
      assert_includes response.body, "No preference"
      assert_includes response.body, "Phone:"
      assert_includes response.body, "415-555-0199"

      UpdateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        office: offices(:one),
        communication_preference: "email"
      ).call

      get directory_clients_path
      assert_response :success
      assert_includes response.body, "Preferred contact unavailable."
      assert_includes response.body, "Phone:"
      assert_includes response.body, "415-555-0199"

      email = CreatePartyContactPoint.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_kind: "email",
        attributes: { display_address: "alex.client@example.com", email_type: "personal" }
      ).call.contact_point
      SetContactPointPrimary.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        contact_point: email,
        purpose: "general"
      ).call

      get directory_clients_path
      assert_response :success
      assert_includes response.body, "alex.client@example.com"
      assert_not_includes response.body, "Preferred contact unavailable."
      assert_not_includes response.body, "Phone:"
      assert_not_includes response.body, "415-555-0199"
    end
  end
end
