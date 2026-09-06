require "test_helper"

class InviteTeamMemberTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "invites a new email and enqueues mail after commit" do
    assert_enqueued_with(job: DeliveryIntentJob) do
      result = InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "new.colleague@example.com",
        role: "staff",
        first_name: "Riley",
        last_name: "Chen",
        **invite_offices
      ).call

      assert result.ok?
      assert result.membership.invited?
      assert result.membership.person_party.present?
      assert_equal agencies(:one).id, result.membership.person_party.agency_id
      assert_equal "Riley Chen", result.membership.agency_display_name
      assert_equal "staff", result.membership.role
      assert_includes agencies(:one).audit_events.pluck(:action), "team.invitation_created"
    end
  end

  test "does not attach or email a user active in another agency" do
    assert_no_enqueued_jobs only: DeliveryIntentJob do
      assert_no_difference("AgencyMembership.count") do
        result = InviteTeamMember.new(
          agency: agencies(:one),
          actor: users(:one),
          email: users(:two).email_address,
          role: "staff",
          first_name: "Casey",
          last_name: "Nguyen",
          **invite_offices
        ).call

        assert_equal :silent, result.status
        assert_equal MembershipCommand::ELIGIBLE_INVITE_NOTICE, result.message
      end
    end
  end

  test "reports an existing same-agency member without a second row" do
    assert_no_enqueued_jobs only: DeliveryIntentJob do
      result = InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: users(:one).email_address,
        role: "staff",
        first_name: "Jordan",
        last_name: "Blake",
        **invite_offices
      ).call

      assert_equal :already_member, result.status
    end
  end

  test "replaces a revoked same-agency invitation without a duplicate row" do
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "revoked@example.com",
      role: "staff",
      first_name: "River",
      last_name: "Adeyemi",
      **invite_offices
    ).call.membership
    RevokeInvitation.new(agency: agencies(:one), actor: users(:one), membership: membership).call

    assert_no_difference("AgencyMembership.count") do
      result = InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "revoked@example.com",
        role: "administrator",
        first_name: "River",
        last_name: "Adeyemi",
        **invite_offices
      ).call

      assert_equal :replaced, result.status
      assert result.membership.invited?
      assert_equal "administrator", result.membership.role
    end
  end

  test "reuses the existing person when that email already has an in-agency membership" do
    membership = agency_memberships(:one)
    original_person_id = membership.person_party_id

    result = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: users(:one).email_address,
      role: "staff",
      first_name: "Other",
      last_name: "Name",
      **invite_offices
    ).call

    assert_equal :already_member, result.status
    assert_equal original_person_id, membership.reload.person_party_id
  end

  test "rejects selecting a different person for an email that already belongs to this agency" do
    error = assert_raises(MembershipCommand::Error) do
      InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: users(:one).email_address,
        role: "staff",
        first_name: "Alex",
        last_name: "Morgan",
        person_party_id: people(:unlinked).party_id,
        **invite_offices
      ).call
    end

    assert_equal :conflict, error.code
  end

  test "rejects inviting a person already linked to a membership" do
    error = assert_raises(MembershipCommand::Error) do
      InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "already-linked@example.com",
        role: "staff",
        first_name: "Jordan",
        last_name: "Blake",
        person_party_id: people(:one).party_id,
        **invite_offices
      ).call
    end

    assert_equal :conflict, error.code
  end

  test "links an unlinked directory person to a new email without copying another user name onto the person" do
    person = people(:unlinked)
    original_given = person.given_name

    result = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "alex.login@example.com",
      role: "staff",
      first_name: "Ignored",
      last_name: "Name",
      person_party_id: person.party_id,
      **invite_offices
    ).call

    assert result.ok?
    assert_equal person.party_id, result.membership.person_party_id
    assert_equal original_given, person.reload.given_name
    assert_equal "Alex Morgan", result.membership.agency_display_name
    assert_equal "alex.login@example.com", result.membership.user.email_address
  end

  test "links an unlinked person to a user who has no membership in this agency" do
    outsider = User.create!(
      email_address: "outsider-no-membership@example.com",
      first_name: "Out",
      last_name: "Sider",
      password: "password",
      password_confirmation: "password"
    )
    person = people(:unlinked)

    result = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: outsider.email_address,
      role: "staff",
      first_name: "Should",
      last_name: "NotApply",
      person_party_id: person.party_id,
      **invite_offices
    ).call

    assert result.ok?
    assert_equal outsider.id, result.membership.user_id
    assert_equal person.party_id, result.membership.person_party_id
    assert_equal "Out", outsider.reload.first_name
    assert_equal "Alex Morgan", result.membership.agency_display_name
  end
end
