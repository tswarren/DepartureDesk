require "test_helper"

module Directory
  class IdentifiersControllerTest < ActionDispatch::IntegrationTest
    test "party identifiers are agency-scoped and omit inactive-role rows from current" do
      sign_in_as(users(:one))
      party = parties(:unlinked)
      profile = assign_client_role!(party, actor: users(:one))
      AddExternalIdentifier.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        identifier_type: "legacy_party_id",
        original_value: "P-77"
      ).call
      AddExternalIdentifier.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        identifier_type: "legacy_client_id",
        issuer: "AMS",
        original_value: "C-77"
      ).call
      DeactivateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        reason: "Paused"
      ).call

      get directory_party_identifiers_path(party)
      assert_response :success
      assert_includes response.body, "P-77"
      assert_not_includes response.body, "C-77"
      assert_select "a[href=?]", directory_party_identifiers_path(party, status: "deactivated")

      get directory_party_identifiers_path(party, status: "deactivated")
      assert_response :success
      assert_includes response.body, "C-77"
    end

    test "cross-agency identifier routes return not found" do
      sign_in_as(users(:one))

      get directory_party_identifiers_path(parties(:two))
      assert_response :not_found

      post directory_party_external_identifiers_path(parties(:two)), params: {
        external_identifier: { identifier_type: "legacy_party_id", original_value: "nope" }
      }
      assert_response :not_found
    end

    test "staff can add a party identifier" do
      sign_in_as(users(:staff_one))

      post directory_party_external_identifiers_path(parties(:unlinked)), params: {
        external_identifier: { identifier_type: "legacy_party_id", original_value: "STAFF-1" }
      }
      assert_redirected_to directory_party_identifiers_path(parties(:unlinked))
      assert_equal "STAFF-1", parties(:unlinked).external_identifiers.last.original_value
    end
  end
end
