require "test_helper"

class PartyRelationshipLifecycleCommandsTest < ActiveSupport::TestCase
  test "does not create a current relationship involving an inactive party" do
    DeactivateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:unlinked),
      reason: "Unused"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      CreatePartyRelationship.new(
        agency: agencies(:one),
        actor: users(:one),
        origin_party: parties(:unlinked),
        related_party: parties(:household_one),
        relationship_kind: "household_member"
      ).call
    end

    assert_equal :invalid, error.code
    assert_match(/Inactive parties/, error.message)
    assert_equal 0, PartyRelationship.involving(parties(:unlinked)).count
  end

  test "does not assign a current purpose involving an inactive party" do
    relationship = CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:maria),
      related_party: parties(:organization_one),
      relationship_kind: "organization_contact"
    ).call.relationship

    parties(:maria).update!(
      status: "deactivated",
      deactivated_at: Time.current,
      deactivated_by_membership: agency_memberships(:one),
      deactivation_reason: "Forced for command check"
    )

    error = assert_raises(MembershipCommand::Error) do
      AssignRelationshipPurpose.new(
        agency: agencies(:one),
        actor: users(:one),
        relationship:,
        purpose: "booking",
        priority: 1
      ).call
    end

    assert_equal :invalid, error.code
    assert_match(/Inactive parties/, error.message)
    assert_equal 0, relationship.purpose_assignments.count
  end
end
