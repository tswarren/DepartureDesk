require "test_helper"

class MembershipCommandOwnershipTest < ActiveSupport::TestCase
  TARGET_COMMANDS = {
    ChangeMembershipRole => ->(agency, membership, **actors) {
      ChangeMembershipRole.new(agency:, membership:, role: "staff", **actors)
    },
    SuspendMembership => ->(agency, membership, **actors) {
      SuspendMembership.new(agency:, membership:, **actors)
    },
    ReactivateMembership => ->(agency, membership, **actors) {
      ReactivateMembership.new(agency:, membership:, **actors)
    },
    ReplaceInvitation => ->(agency, membership, **actors) {
      ReplaceInvitation.new(agency:, membership:, **actors)
    },
    RevokeInvitation => ->(agency, membership, **actors) {
      RevokeInvitation.new(agency:, membership:, **actors)
    }
  }.freeze

  test "mismatched agency and membership leave both agencies unchanged" do
    TARGET_COMMANDS.each do |command_class, builder|
      membership = agency_memberships(:two)
      snapshot = membership_snapshot(membership)
      agency_one_audits = agencies(:one).audit_events.count
      agency_two_audits = agencies(:two).audit_events.count

      error = assert_raises(MembershipCommand::Error, command_class.name) do
        builder.call(agencies(:one), membership, actor: users(:one)).call
      end

      assert_equal :invalid, error.code, command_class.name
      assert_equal snapshot, membership_snapshot(membership.reload), command_class.name
      assert_equal "Pacific Travel", agencies(:two).reload.name
      assert_equal "Sunrise Travel", agencies(:one).reload.name
      assert_equal agency_one_audits, agencies(:one).audit_events.count, command_class.name
      assert_equal agency_two_audits, agencies(:two).audit_events.count, command_class.name
    end
  end

  test "a staff actor cannot mutate a membership" do
    staff = invite_and_accept
    snapshot = membership_snapshot(staff)
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      ChangeMembershipRole.new(
        agency: agencies(:one),
        membership: staff,
        role: "administrator",
        actor: staff.user
      ).call
    end

    assert_equal :unauthorized, error.code
    assert_equal snapshot, membership_snapshot(staff.reload)
    assert_equal audits, AuditEvent.count
  end

  test "an administrator from another agency cannot mutate a membership" do
    membership = agency_memberships(:two)
    snapshot = membership_snapshot(membership)
    audits = agencies(:two).audit_events.count

    error = assert_raises(MembershipCommand::Error) do
      SuspendMembership.new(
        agency: agencies(:two),
        membership: membership,
        actor: users(:one)
      ).call
    end

    assert_equal :unauthorized, error.code
    assert_equal snapshot, membership_snapshot(membership.reload)
    assert_equal audits, agencies(:two).audit_events.count
  end

  test "missing both actors is unauthorized and writes no audit" do
    membership = invite_staff
    snapshot = membership_snapshot(membership)
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      RevokeInvitation.new(
        agency: agencies(:one),
        membership: membership
      ).call
    end

    assert_equal :unauthorized, error.code
    assert_equal snapshot, membership_snapshot(membership.reload)
    assert_equal audits, AuditEvent.count
  end

  test "actor_identifier on a tenant-only command is unauthorized" do
    membership = invite_staff
    snapshot = membership_snapshot(membership)
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      ReplaceInvitation.new(
        agency: agencies(:one),
        membership: membership,
        actor_identifier: "ops:should-not-work"
      ).call
    end

    assert_equal :unauthorized, error.code
    assert_equal snapshot, membership_snapshot(membership.reload)
    assert_equal audits, AuditEvent.count
  end

  test "privileged system attribution can reactivate when explicitly opted in" do
    staff = invite_and_accept
    SuspendMembership.new(agency: agencies(:one), actor: users(:one), membership: staff).call

    ReactivateMembership.new(
      agency: agencies(:one),
      membership: staff,
      actor_identifier: "ops:recovery",
      privileged: true
    ).call

    assert staff.reload.active?
    event = agencies(:one).audit_events.order(:created_at).last
    assert_equal "team.membership_reactivated", event.action
    assert_equal "system", event.actor_kind
    assert_equal "ops:recovery", event.actor_identifier
  end

  test "unknown activation modes are rejected before locking" do
    membership = agency_memberships(:one)

    error = assert_raises(MembershipCommand::Error) do
      ActivateMembership.new(
        agency: agencies(:one),
        membership: membership,
        mode: :typo,
        actor: users(:one)
      ).call
    end

    assert_equal :invalid, error.code
    assert membership.reload.active?
  end

  test "acceptance still audits the invitee" do
    membership = invite_staff
    token = membership.invitation_token

    AcceptInvitation.new(
      token: token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call

    event = AuditEvent.order(:created_at).last
    assert_equal "team.invitation_accepted", event.action
    assert_equal "user", event.actor_kind
    assert_equal membership.user_id, event.actor_user_id
    assert_nil event.actor_identifier
  end

  test "unknown roles are rejected before mutation" do
    staff = invite_and_accept
    snapshot = membership_snapshot(staff)
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      ChangeMembershipRole.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: staff,
        role: "superadmin"
      ).call
    end

    assert_equal :invalid_role, error.code
    assert_equal snapshot, membership_snapshot(staff.reload)
    assert_equal audits, AuditEvent.count
  end

  private

  def membership_snapshot(membership)
    membership.attributes.slice("id", "agency_id", "status", "role", "invitation_version", "lock_version")
  end

  def invite_staff(email: "ownership-staff@example.com")
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
    membership = invite_staff(email: "ownership-accepted@example.com")
    AcceptInvitation.new(
      token: membership.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call.membership
  end
end
