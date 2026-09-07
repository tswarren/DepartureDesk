require "test_helper"

module Directory
  class RelationshipsControllerTest < ActionDispatch::IntegrationTest
    test "staff can create a household membership" do
      sign_in_as(users(:two))

      post directory_party_party_relationships_path(parties(:two)), params: {
        party_relationship: {
          relationship_kind: "family",
          relationship_label: "other_family",
          other_party_id: CreateParty.new(
            agency: agencies(:two),
            actor: users(:two),
            party_kind: "person",
            attributes: { given_name: "Sam", family_name: "Peer" }
          ).call.party.id
        }
      }
      assert_redirected_to directory_party_relationships_path(parties(:two))
    end

    test "cross-agency relationship pages return not found" do
      sign_in_as(users(:one))

      get directory_party_relationships_path(parties(:two))
      assert_response :not_found
    end

    test "the add-relationship filter is not nested inside the create form" do
      sign_in_as(users(:one))
      party = parties(:unlinked)

      get new_directory_party_party_relationship_path(party)
      assert_response :success
      assert_select "form[method=get][action=?]", new_directory_party_party_relationship_path(party)
      assert_select "form[action=?]", directory_party_party_relationships_path(party) do
        assert_select "select#relationship_kind"
        assert_select "select#other_party_id"
        assert_select "input[type=submit][value='Add relationship']"
      end
      assert_select "form form", count: 0
    end

    test "incompatible kinds are rejected by the server" do
      sign_in_as(users(:one))

      post directory_party_party_relationships_path(parties(:unlinked)), params: {
        party_relationship: {
          relationship_kind: "household_member",
          other_party_id: parties(:organization_one).id
        }
      }
      assert_response :unprocessable_entity
    end
  end
end
