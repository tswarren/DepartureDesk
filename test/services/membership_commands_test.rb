require "test_helper"

class MembershipCommandsTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "invited memberships are never usable" do
    membership = invite_staff
    assert_predicate membership, :invited?
    assert_nil membership.user.usable_agency_membership
  end

  test "replace invitation invalidates the previous token" do
    membership = invite_staff
    old_token = membership.invitation_token

    ReplaceInvitation.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: membership
    ).call

    assert_nil AgencyMembership.find_by_token_for(:invitation, old_token)
    assert AgencyMembership.find_by_token_for(:invitation, membership.reload.invitation_token)
    assert_equal "team.invitation_replaced", AuditEvent.last.action
  end

  test "failed acceptance does not increment invitation_version" do
    membership = invite_staff
    version = membership.invitation_version

    assert_raises(MembershipCommand::Error) do
      AcceptInvitation.new(
        token: "not-a-token",
        password: "password",
        password_confirmation: "password"
      ).call
    end

    assert_equal version, membership.reload.invitation_version
  end

  test "acceptance activates membership and records audit" do
    membership = invite_staff
    token = membership.invitation_token

    result = AcceptInvitation.new(
      token: token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call

    assert result.membership.active?
    assert_equal "team.invitation_accepted", AuditEvent.last.action
    assert_nil AgencyMembership.find_by_token_for(:invitation, token)
    assert User.authenticate_by(email_address: membership.user.email_address, password: "Newpass123!")
  end

  test "last administrator cannot be suspended" do
    assert_raises(MembershipCommand::Error) do
      SuspendMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:one)
      ).call
    end

    assert agency_memberships(:one).reload.active?
  end

  test "last administrator cannot be demoted" do
    assert_raises(MembershipCommand::Error) do
      ChangeMembershipRole.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:one),
        role: "staff"
      ).call
    end

    assert agency_memberships(:one).reload.administrator?
  end

  test "suspension destroys the target user's sessions" do
    staff = invite_and_accept
    staff.user.sessions.create!
    assert_difference("Session.where(user: staff.user).count", -1) do
      SuspendMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: staff
      ).call
    end
    assert staff.reload.suspended?
  end

  test "reactivation does not create or destroy sessions" do
    staff = invite_and_accept
    SuspendMembership.new(agency: agencies(:one), actor: users(:one), membership: staff).call

    assert_no_difference("Session.count") do
      ReactivateMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: staff.reload
      ).call
    end
    assert staff.reload.active?
  end

  test "revoking a pending invitation does not destroy sessions" do
    membership = invite_staff
    users(:one).sessions.create!

    assert_no_difference("Session.count") do
      RevokeInvitation.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: membership
      ).call
    end
    assert membership.reload.revoked?
  end

  private

  def invite_staff(email: "staff.invite@example.com")
    InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: email,
      role: "staff",
      first_name: "Quinn",
      last_name: "Okoye"
    ).call.membership
  end

  def invite_and_accept
    membership = invite_staff
    AcceptInvitation.new(
      token: membership.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call.membership
  end
end
