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
      assert_select "a[href=?]", directory_suppliers_path, text: "Suppliers"

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

    test "cross-agency office ids return not found on create update and reactivate" do
      sign_in_as(users(:one))
      party = parties(:organization_one)

      post directory_party_client_profile_path(party), params: {
        client_profile: { responsible_office_id: offices(:two).id }
      }
      assert_response :not_found
      assert_nil party.reload.client_profile

      post directory_party_supplier_profile_path(party), params: {
        supplier_profile: { responsible_office_id: offices(:two).id }
      }
      assert_response :not_found
      assert_nil party.reload.supplier_profile

      profile = assign_client_role!(party, actor: users(:one))
      patch directory_party_client_profile_path(party), params: {
        client_profile: {
          responsible_office_id: offices(:two).id,
          lock_version: profile.lock_version
        }
      }
      assert_response :not_found
      assert_equal offices(:one).id, profile.reload.responsible_office_id

      DeactivateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        reason: "Paused"
      ).call
      post reactivate_directory_party_client_profile_path(party), params: {
        client_profile: {
          responsible_office_id: offices(:two).id,
          lock_version: profile.reload.lock_version
        }
      }
      assert_response :not_found
      assert profile.reload.inactive?

      supplier = assign_supplier_role!(party, actor: users(:one))
      patch directory_party_supplier_profile_path(party), params: {
        supplier_profile: {
          responsible_office_id: offices(:two).id,
          lock_version: supplier.lock_version
        }
      }
      assert_response :not_found
      assert_equal offices(:one).id, supplier.reload.responsible_office_id

      DeactivateSupplierProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile: supplier,
        reason: "Paused"
      ).call
      post reactivate_directory_party_supplier_profile_path(party), params: {
        supplier_profile: {
          responsible_office_id: offices(:two).id,
          lock_version: supplier.reload.lock_version
        }
      }
      assert_response :not_found
      assert supplier.reload.inactive?
    end

    test "staff can assign an advisor from the party page" do
      sign_in_as(users(:staff_one))
      party = parties(:organization_one)
      profile = assign_client_role!(party, actor: users(:staff_one))

      get directory_party_path(party)
      assert_response :success
      assert_select "select[name='client_profile[primary_advisor_membership_id]'] option[value=?]",
        agency_memberships(:staff_one).id,
        text: /Riley Staff/
      assert_select "select[name='client_profile[primary_advisor_membership_id]'] option[value=?]",
        agency_memberships(:one).id,
        text: /Jordan Blake/

      post assign_advisor_directory_party_client_profile_path(party), params: {
        client_profile: {
          primary_advisor_membership_id: agency_memberships(:one).id,
          lock_version: profile.lock_version
        }
      }
      assert_redirected_to directory_party_path(party)
      follow_redirect!
      assert_includes response.body, "Client advisor updated."
      assert_equal agency_memberships(:one).id, profile.reload.primary_advisor_membership_id

      post clear_advisor_directory_party_client_profile_path(party), params: {
        client_profile: { lock_version: profile.lock_version }
      }
      assert_redirected_to directory_party_path(party)
      assert_nil profile.reload.primary_advisor_membership_id
    end

    test "cross-agency advisor ids return not found" do
      sign_in_as(users(:one))
      party = parties(:organization_one)
      profile = assign_client_role!(party, actor: users(:one))

      post assign_advisor_directory_party_client_profile_path(party), params: {
        client_profile: {
          primary_advisor_membership_id: agency_memberships(:two).id,
          lock_version: profile.lock_version
        }
      }
      assert_response :not_found
      assert_nil profile.reload.primary_advisor_membership_id
    end

    test "a blank advisor id is a validation error" do
      sign_in_as(users(:one))
      party = parties(:organization_one)
      profile = assign_client_role!(party, actor: users(:one))

      post assign_advisor_directory_party_client_profile_path(party), params: {
        client_profile: {
          primary_advisor_membership_id: "",
          lock_version: profile.lock_version
        }
      }
      assert_redirected_to directory_party_path(party)
      follow_redirect!
      assert_includes response.body, "Choose an active team member as advisor."
      assert_nil profile.reload.primary_advisor_membership_id
    end

    test "client update ignores status and does not copy restriction bodies into flash only through the command" do
      sign_in_as(users(:one))
      party = parties(:organization_one)
      profile = assign_client_role!(party, actor: users(:one))

      patch directory_party_client_profile_path(party), params: {
        client_profile: {
          responsible_office_id: offices(:one).id,
          communication_preference: "phone",
          servicing_restrictions: "Weekday calls only.",
          status: "inactive",
          lock_version: profile.lock_version
        }
      }
      assert_redirected_to directory_party_path(party)
      profile.reload
      assert profile.active?
      assert_equal "phone", profile.communication_preference
      assert_equal "Weekday calls only.", profile.servicing_restrictions
    end

    test "staff can add a supplier category from the party page" do
      sign_in_as(users(:staff_one))
      party = parties(:organization_one)
      assign_supplier_role!(party, actor: users(:staff_one))

      post assign_category_directory_party_supplier_profile_path(party), params: {
        supplier_profile: { category_code: "accommodation" }
      }
      assert_redirected_to directory_party_path(party)
      follow_redirect!
      assert_includes response.body, "Supplier category added."
      assert_includes response.body, "Accommodation"

      post remove_category_directory_party_supplier_profile_path(party), params: {
        supplier_profile: { category_code: "accommodation" }
      }
      assert_redirected_to directory_party_path(party)
      assert_equal [], party.reload.supplier_profile.category_codes
    end

    test "a blank office id is a validation error" do
      sign_in_as(users(:one))
      party = parties(:organization_one)

      post directory_party_client_profile_path(party), params: {
        client_profile: { responsible_office_id: "" }
      }
      assert_redirected_to directory_party_path(party)
      follow_redirect!
      assert_includes response.body, "Choose an active office."
      assert_nil party.reload.client_profile
    end
  end
end
