require "test_helper"

class OfficeInviteActivateTest < ActiveSupport::TestCase
  test "staff invite without offices fails when offices exist" do
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "no-office@example.com",
        role: "staff",
        first_name: "No",
        last_name: "Office"
      ).call
    end

    assert_equal :invalid, error.code
    assert_not User.exists?(email_address: "no-office@example.com")
    assert_equal audits, AuditEvent.count
  end

  test "administrator invite requires a default office when one exists" do
    error = assert_raises(MembershipCommand::Error) do
      InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "admin-no-default@example.com",
        role: "administrator",
        first_name: "Ada",
        last_name: "Min"
      ).call
    end

    assert_equal :invalid, error.code
  end

  test "staff invite grants intended offices and a default" do
    result = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "office-staff@example.com",
      role: "staff",
      first_name: "Pat",
      last_name: "Ng",
      **invite_offices
    ).call

    assert result.membership.invited?
    assert result.membership.has_active_office_assignment?
    assert_equal offices(:one), result.membership.default_office
  end

  test "public accept without a staff assignment stays generic and does not change the password" do
    user = User.create!(
      email_address: "bare-staff@example.com",
      first_name: "Bare",
      last_name: "Staff",
      password: "OriginalPass123!",
      password_confirmation: "OriginalPass123!"
    )
    membership = AgencyMembership.create!(
      user:,
      agency: agencies(:one),
      person_party: create_person!(agencies(:one), given_name: user.first_name, family_name: user.last_name),
      role: "staff",
      status: "invited",
      invitation_sent_at: Time.current
    )
    original_digest = user.password_digest

    error = assert_raises(MembershipCommand::Error) do
      AcceptInvitation.new(
        token: membership.invitation_token,
        password: "Newpass123!",
        password_confirmation: "Newpass123!"
      ).call
    end

    assert_equal :invalid_token, error.code
    assert_equal AcceptInvitation::GENERIC_FAILURE, error.message
    assert membership.reload.invited?
    assert_equal original_digest, user.reload.password_digest
  end

  test "administrators cannot accept without a default when an active office exists" do
    user = User.create!(
      email_address: "bare-admin@example.com",
      first_name: "Bare",
      last_name: "Admin",
      password: "OriginalPass123!",
      password_confirmation: "OriginalPass123!"
    )
    membership = AgencyMembership.create!(
      user:,
      agency: agencies(:one),
      person_party: create_person!(agencies(:one), given_name: user.first_name, family_name: user.last_name),
      role: "administrator",
      status: "invited",
      invitation_sent_at: Time.current
    )
    original_digest = user.password_digest

    error = assert_raises(MembershipCommand::Error) do
      AcceptInvitation.new(
        token: membership.invitation_token,
        password: "Newpass123!",
        password_confirmation: "Newpass123!"
      ).call
    end

    assert_equal :invalid_token, error.code
    assert_equal AcceptInvitation::GENERIC_FAILURE, error.message
    assert membership.reload.invited?
    assert_equal original_digest, user.reload.password_digest
  end

  test "staff reactivation without an assignment returns no_office_access" do
    staff = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "reactivate-staff@example.com",
      role: "staff",
      first_name: "Pat",
      last_name: "Ng",
      **invite_offices
    ).call.membership
    AcceptInvitation.new(
      token: staff.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call
    SuspendMembership.new(agency: agencies(:one), actor: users(:one), membership: staff).call
    RevokeOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: staff,
      office: offices(:one)
    ).call

    error = assert_raises(MembershipCommand::Error) do
      ReactivateMembership.new(agency: agencies(:one), actor: users(:one), membership: staff).call
    end

    assert_equal :no_office_access, error.code
    assert staff.reload.suspended?
  end

  test "replacement invitation revokes omitted offices" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "replace-offices@example.com",
      role: "staff",
      first_name: "River",
      last_name: "Adeyemi",
      office_ids: [ offices(:one).id, extra.id ],
      default_office_id: offices(:one).id
    ).call.membership

    InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "replace-offices@example.com",
      role: "staff",
      first_name: "River",
      last_name: "Adeyemi",
      office_ids: [ extra.id ],
      default_office_id: extra.id
    ).call

    membership.reload
    assert_equal extra, membership.default_office
    assert_not membership.office_assignments.active.exists?(office: offices(:one))
    assert membership.office_assignments.find_by!(office: offices(:one)).revoked?
  end

  test "failed replacement reconciliation leaves the invitation unchanged" do
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "failed-replace@example.com",
      role: "staff",
      first_name: "River",
      last_name: "Adeyemi",
      **invite_offices
    ).call.membership
    version = membership.invitation_version
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      InviteTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        email: "failed-replace@example.com",
        role: "staff",
        first_name: "River",
        last_name: "Adeyemi",
        office_ids: [],
        default_office_id: nil
      ).call
    end

    assert_equal :invalid, error.code
    assert_equal version, membership.reload.invitation_version
    assert_equal offices(:one), membership.default_office
    assert_equal audits, AuditEvent.count
  end

  test "silent cross-agency invites attach no assignment" do
    assert_no_difference("OfficeAssignment.count") do
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
    end
  end
end
