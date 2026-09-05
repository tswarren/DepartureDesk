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
        last_name: "Chen"
      ).call

      assert result.ok?
      assert result.membership.invited?
      assert_equal "staff", result.membership.role
      assert_equal "team.invitation_created", AuditEvent.last.action
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
          last_name: "Nguyen"
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
        last_name: "Blake"
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
      last_name: "Adeyemi"
    ).call.membership
    RevokeInvitation.new(agency: agencies(:one), actor: users(:one), membership: membership).call

    assert_no_difference("AgencyMembership.count") do
      result = InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "revoked@example.com",
        role: "administrator",
        first_name: "River",
        last_name: "Adeyemi"
      ).call

      assert_equal :replaced, result.status
      assert result.membership.invited?
      assert_equal "administrator", result.membership.role
    end
  end
end
