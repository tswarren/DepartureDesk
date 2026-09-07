require "test_helper"

class PartyLifecycleCommandsTest < ActiveSupport::TestCase
  test "staff can deactivate and reactivate an unblocked party" do
    party = parties(:unlinked)

    DeactivateParty.new(
      agency: agencies(:one),
      actor: users(:staff_one),
      party:,
      reason: "Unused duplicate"
    ).call
    assert party.reload.deactivated?
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.party_deactivated"

    results = DirectoryPartySelector.new(agency: agencies(:one), q: "Alex").results
    assert_not_includes results.map(&:party_id), party.id

    included = DirectoryPartySelector.new(agency: agencies(:one), q: "Alex", include_inactive: true).results
    assert_includes included.map(&:party_id), party.id

    ReactivateParty.new(
      agency: agencies(:one),
      actor: users(:staff_one),
      party:,
      reason: "Needed again"
    ).call
    assert party.reload.active?
    assert_nil party.deactivation_reason
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.party_reactivated"
    assert_nil party.client_profile
  end

  test "membership link blocks person deactivation" do
    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:one),
        reason: "Leave"
      ).call
    end
    assert_equal :party_dependency, error.code
    assert_match(/Team membership/, error.message)
    assert parties(:one).reload.active?
  end

  test "active client role blocks deactivation" do
    assign_client_role!(parties(:unlinked), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:unlinked),
        reason: "Leave"
      ).call
    end
    assert_equal :party_dependency, error.code
    assert_match(/client/, error.message)
  end

  test "active supplier role blocks deactivation and role deactivation does not deactivate the party" do
    profile = assign_supplier_role!(parties(:organization_one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:organization_one),
        reason: "Leave"
      ).call
    end
    assert_equal :party_dependency, error.code
    assert_match(/supplier/, error.message)

    DeactivateSupplierProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:organization_one),
      profile:,
      reason: "Season over"
    ).call
    assert parties(:organization_one).reload.active?
    assert profile.reload.inactive?

    DeactivateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party: parties(:organization_one),
      reason: "No longer used"
    ).call
    assert parties(:organization_one).reload.deactivated?
    assert profile.reload.inactive?
  end

  test "current household membership blocks both sides" do
    CreatePartyRelationship.new(
      agency: agencies(:one),
      actor: users(:one),
      origin_party: parties(:unlinked),
      related_party: parties(:household_one),
      relationship_kind: "household_member"
    ).call

    person_error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:unlinked),
        reason: "Leave"
      ).call
    end
    assert_match(/household membership/, person_error.message)

    household_error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:household_one),
        reason: "Leave"
      ).call
    end
    assert_match(/household membership/, household_error.message)
  end

  test "blank reason is rejected" do
    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(
        agency: agencies(:one),
        actor: users(:one),
        party: parties(:unlinked),
        reason: "  "
      ).call
    end
    assert_equal :invalid, error.code
  end

  test "reactivation does not restore a deactivated client role" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    DeactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      reason: "Paused"
    ).call
    DeactivateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      reason: "Unused"
    ).call
    ReactivateParty.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      reason: "Back"
    ).call

    assert party.reload.active?
    assert profile.reload.inactive?
    assert_nil profile.party_status
  end
end
