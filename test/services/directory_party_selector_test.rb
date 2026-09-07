require "test_helper"

class DirectoryPartySelectorTest < ActiveSupport::TestCase
  test "returns party uuids and role metadata without profile ids as identity" do
    assign_client_role!(parties(:unlinked), actor: users(:one))
    results = DirectoryPartySelector.new(agency: agencies(:one), mode: "active_client", q: "Alex").results

    assert_equal [ parties(:unlinked).id ], results.map(&:party_id)
    assert_equal "active", results.first.client_status
    assert_nil results.first.supplier_status
    assert_no_match(/client_profile/i, results.first.to_h.keys.join)
  end

  test "mode filters cover client supplier team member and household exclusion" do
    assign_client_role!(parties(:household_one), actor: users(:one))
    assign_supplier_role!(parties(:organization_one), actor: users(:one))

    any_without_household = DirectoryPartySelector.new(agency: agencies(:one), mode: "any", household_allowed: false).results
    assert_not(any_without_household.any? { |result| result.party_kind == "household" })

    clients = DirectoryPartySelector.new(agency: agencies(:one), mode: "client").results
    assert_includes clients.map(&:party_id), parties(:household_one).id

    suppliers = DirectoryPartySelector.new(agency: agencies(:one), mode: "active_supplier").results
    assert_equal [ parties(:organization_one).id ], suppliers.map(&:party_id)

    people = DirectoryPartySelector.new(agency: agencies(:one), mode: "person", q: "Jordan").results
    assert_equal [ parties(:one).id ], people.map(&:party_id)
    assert people.first.team_member

    members = DirectoryPartySelector.new(agency: agencies(:one), mode: "team_member").results
    assert_includes members.map(&:party_id), parties(:one).id
    assert_not_includes members.map(&:party_id), parties(:unlinked).id
  end

  test "supplier contact mode returns related people not the supplier party" do
    assign_supplier_role!(parties(:organization_one), actor: users(:one))
    CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:maria),
      related_party: parties(:organization_one),
      relationship_kind: "organization_contact"
    ).call

    results = DirectoryPartySelector.new(agency: agencies(:one), mode: "supplier_contact").results
    assert_equal [ parties(:maria).id ], results.map(&:party_id)
    assert_nil results.first.supplier_status
  end

  test "prefix filter is not a contains match" do
    results = DirectoryPartySelector.new(agency: agencies(:one), mode: "any", q: "Alex").results
    assert_includes results.map(&:display_name), "Alex Morgan"
    assert_not_includes results.map(&:display_name), "Morgan Household"
  end
end
