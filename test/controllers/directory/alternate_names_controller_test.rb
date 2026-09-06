require "test_helper"

module Directory
  class AlternateNamesControllerTest < ActionDispatch::IntegrationTest
    test "nested create update and removal stay on the party and are audited" do
      sign_in_as(users(:one))
      party = parties(:unlinked)

      post directory_party_alternate_names_path(party), params: {
        party_alternate_name: { name: "Alexander Morgan", name_kind: "former_name" }
      }
      assert_redirected_to directory_party_path(party)
      follow_redirect!
      assert_select "strong.dd-list-title", text: "Alexander Morgan"
      alternate = party.alternate_names.find_by!(normalized_name: "alexander morgan")
      assert alternate.active?
      assert_includes agencies(:one).audit_events.pluck(:action), "directory.alternate_name_added"

      patch directory_party_alternate_name_path(party, alternate), params: {
        party_alternate_name: { name: "Alex J. Morgan", name_kind: "former_name" }
      }
      assert_redirected_to directory_party_path(party)
      assert_equal "Alex J. Morgan", alternate.reload.name
      assert_includes agencies(:one).audit_events.pluck(:action), "directory.alternate_name_updated"

      assert_no_difference("PartyAlternateName.count") do
        delete directory_party_alternate_name_path(party, alternate)
      end
      assert_redirected_to directory_party_path(party)
      assert alternate.reload.removed?
      assert_includes agencies(:one).audit_events.pluck(:action), "directory.alternate_name_removed"
    end

    test "cross-agency nested routes are not found" do
      sign_in_as(users(:one))

      post directory_party_alternate_names_path(parties(:two)), params: {
        party_alternate_name: { name: "Foreign", name_kind: "alias" }
      }
      assert_response :not_found
    end
  end
end
