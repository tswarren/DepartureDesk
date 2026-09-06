require "test_helper"

module Directory
  class RoleProfilesControllerTest < ActionDispatch::IntegrationTest
    test "administrator can add deactivate and reactivate roles on the party page" do
      sign_in_as(users(:one))
      party = parties(:organization_one)

      get directory_party_path(party)
      assert_response :success
      assert_includes response.body, "Roles"
      assert_includes response.body, "Add client role"
      assert_includes response.body, "Add supplier role"
      assert_select "span[aria-disabled=true]", text: "Suppliers"

      post directory_party_client_profile_path(party), params: {
        client_profile: { responsible_office_id: offices(:one).id }
      }
      assert_redirected_to directory_party_path(party)
      follow_redirect!
      assert_includes response.body, "Client role added."
      assert_select "h3.dd-list-title", text: "Client"
      assert_includes response.body, "Sunrise Travel (MAIN)"

      profile = party.reload.client_profile
      post deactivate_directory_party_client_profile_path(party), params: {
        client_profile: { reason: "No longer a client", lock_version: profile.lock_version }
      }
      assert_redirected_to directory_party_path(party)
      assert profile.reload.inactive?

      post reactivate_directory_party_client_profile_path(party), params: {
        client_profile: {
          responsible_office_id: offices(:one).id,
          lock_version: profile.lock_version
        }
      }
      assert_redirected_to directory_party_path(party)
      assert profile.reload.active?
    end

    test "staff can add a supplier role" do
      sign_in_as(users(:staff_one))
      party = parties(:organization_one)

      post directory_party_supplier_profile_path(party), params: {
        supplier_profile: { responsible_office_id: offices(:one).id }
      }
      assert_redirected_to directory_party_path(party)
      assert party.reload.supplier_profile.active?
    end

    test "household overview has no supplier action" do
      sign_in_as(users(:one))

      get directory_party_path(parties(:household_one))
      assert_response :success
      assert_includes response.body, "Ineligible"
      assert_includes response.body, "Households cannot hold a supplier role."
      assert_not_includes response.body, "Add supplier role"

      post directory_party_supplier_profile_path(parties(:household_one)), params: {
        supplier_profile: { responsible_office_id: offices(:one).id }
      }
      assert_redirected_to directory_party_path(parties(:household_one))
      follow_redirect!
      assert_includes response.body, "Households cannot be suppliers."
      assert_nil parties(:household_one).reload.supplier_profile
    end

    test "roles remain visible after changing current office" do
      sign_in_as(users(:one))
      assign_client_role!(parties(:organization_one), actor: users(:one))
      extra = CreateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        name: "Boston",
        code: "BOS",
        default_timezone: agencies(:one).default_timezone
      ).call.office
      patch current_office_path, params: { office_id: extra.id }
      assert_redirected_to root_url

      get directory_party_path(parties(:organization_one))
      assert_response :success
      assert_includes response.body, "Roles"
      assert_includes response.body, "Sunrise Travel (MAIN)"
    end

    test "cross-agency role routes return not found" do
      sign_in_as(users(:one))

      post directory_party_client_profile_path(parties(:two)), params: {
        client_profile: { responsible_office_id: offices(:one).id }
      }
      assert_response :not_found
      assert_nil parties(:two).reload.client_profile
    end
  end
end
