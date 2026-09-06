require "test_helper"

module Directory
  class PartiesControllerTest < ActionDispatch::IntegrationTest
    test "administrator can list view create and edit parties" do
      sign_in_as(users(:one))

      get directory_parties_path
      assert_response :success
      assert_includes response.body, parties(:one).display_name
      assert_includes response.body, parties(:household_one).display_name
      assert_includes response.body, parties(:organization_one).display_name
      assert_not_includes response.body, parties(:two).display_name
      assert_select "nav[aria-label='Primary navigation'] a[aria-current=page]", text: "Directory"
      assert_select "nav[aria-label=Administration]", count: 0

      get new_directory_party_path
      assert_response :success
      assert_select "a", text: "Person"

      get new_directory_party_path(party_kind: "person")
      assert_response :success
      assert_select "input[name='party[given_name]']"

      assert_difference("Party.count", 1) do
        post directory_parties_path, params: {
          party: {
            party_kind: "person",
            agency_id: agencies(:two).id,
            given_name: "Pat",
            family_name: "Lee"
          }
        }
      end
      party = agencies(:one).parties.find_by!(display_name: "Pat Lee")
      assert_redirected_to directory_party_path(party)
      assert_equal agencies(:one).id, party.agency_id
      assert_equal "person", party.party_kind

      get directory_party_path(party)
      assert_response :success
      assert_includes response.body, "Pat Lee"

      get edit_directory_party_path(party)
      assert_response :success

      patch directory_party_path(party), params: {
        party: {
          party_kind: "organization",
          preferred_name: "Patricia",
          given_name: "Pat",
          family_name: "Lee",
          lock_version: party.lock_version,
          profile_lock_version: party.person.lock_version
        }
      }
      assert_redirected_to directory_party_path(party)
      assert_equal "person", party.reload.party_kind
      assert_equal "Patricia Lee", party.display_name
    end

    test "staff can list view create and edit parties" do
      sign_in_as(users(:two))

      get directory_parties_path
      assert_response :success
      assert_includes response.body, parties(:two).display_name
      assert_not_includes response.body, parties(:one).display_name

      post directory_parties_path, params: {
        party: { party_kind: "household", name: "Staff Household" }
      }
      household = agencies(:two).parties.find_by!(display_name: "Staff Household")
      assert_redirected_to directory_party_path(household)
      assert_equal "household", household.party_kind

      get directory_party_path(parties(:two))
      assert_response :success

      patch directory_party_path(parties(:two)), params: {
        party: {
          given_name: "Casey",
          family_name: "Nguyen",
          preferred_name: "Cas",
          lock_version: parties(:two).lock_version,
          profile_lock_version: people(:two).lock_version
        }
      }
      assert_redirected_to directory_party_path(parties(:two))
      assert_equal "Cas Nguyen", parties(:two).reload.display_name
    end

    test "unauthenticated requests redirect to sign in" do
      get directory_parties_path
      assert_redirected_to new_session_path
    end

    test "cross-agency show and update return not found" do
      sign_in_as(users(:one))

      get directory_party_path(parties(:two))
      assert_response :not_found

      patch directory_party_path(parties(:two)), params: {
        party: { given_name: "Hacked", family_name: "Name", lock_version: 0, profile_lock_version: 0 }
      }
      assert_response :not_found
    end

    test "kind filter stays inside the current agency" do
      sign_in_as(users(:one))

      get directory_parties_path, params: { party_kind: "person" }

      assert_response :success
      assert_includes response.body, parties(:one).display_name
      assert_not_includes response.body, parties(:household_one).display_name
      assert_not_includes response.body, parties(:two).display_name
      assert_select "button[type=submit]", text: "Apply filter"
      assert_select "[onchange]", count: 0
    end

    test "directory index paginates by sort name and id" do
      sign_in_as(users(:one))
      CreateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party_kind: "person",
        attributes: { given_name: "Pat", family_name: "Lee" }
      ).call

      previous_page_size = Directory::PartiesController.page_size
      Directory::PartiesController.page_size = 2
      begin
        get directory_parties_path, params: { party_kind: "person" }
        assert_response :success
        assert_includes response.body, parties(:one).display_name
        assert_select "a", text: "Next"
        assert_select "a", text: "Previous", count: 0

        get directory_parties_path, params: { party_kind: "person", page: 2 }
        assert_response :success
        assert_includes response.body, parties(:unlinked).display_name
        assert_not_includes response.body, parties(:one).display_name
        assert_select "a", text: "Previous"
      ensure
        Directory::PartiesController.page_size = previous_page_size
      end
    end

    test "directory index and show do not filter by current office" do
      sign_in_as(users(:one))
      extra = CreateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        name: "Boston",
        code: "BOS",
        default_timezone: agencies(:one).default_timezone
      ).call.office
      patch current_office_path, params: { office_id: extra.id }
      assert_redirected_to root_url

      get directory_parties_path
      assert_response :success
      assert_includes response.body, parties(:one).display_name
      assert_includes response.body, parties(:organization_one).display_name

      get directory_party_path(parties(:household_one))
      assert_response :success
      assert_includes response.body, "Morgan Household"
    end

    test "validation errors render accessibly" do
      sign_in_as(users(:one))

      post directory_parties_path, params: {
        party: { party_kind: "person", given_name: "", family_name: "" }
      }

      assert_response :unprocessable_entity
      assert_select "[aria-invalid=true]"
    end
  end
end
