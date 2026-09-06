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
