require "test_helper"

class OfficeCommandsTest < ActiveSupport::TestCase
  test "creates an office and writes an audit" do
    result = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: "America/New_York"
    ).call

    assert result.office.active?
    assert_equal "BOS", result.office.code
    assert_equal "office.created", AuditEvent.order(:created_at).last.action
  end

  test "update ignores a forged code and status" do
    office = offices(:one)

    UpdateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      office: office,
      name: "Sunrise Desk",
      default_timezone: office.default_timezone
    ).call

    office.reload
    assert_equal "Sunrise Desk", office.name
    assert_equal "MAIN", office.code
    assert office.active?
  end

  test "the last active office cannot be deactivated" do
    error = assert_raises(MembershipCommand::Error) do
      ChangeOfficeStatus.new(
        agency: agencies(:one),
        actor: users(:one),
        office: offices(:one),
        to: "inactive",
        reason: "Closing"
      ).call
    end

    assert_equal :last_office, error.code
    assert offices(:one).reload.active?
    assert_not AuditEvent.exists?(action: "office.deactivated", subject_id: offices(:one).id)
  end

  test "staff cannot mutate offices or assignments" do
    staff = invite_and_accept
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      CreateOffice.new(
        agency: agencies(:one),
        actor: staff.user,
        name: "Boston",
        code: "BOS"
      ).call
    end
    assert_equal :unauthorized, error.code

    error = assert_raises(MembershipCommand::Error) do
      GrantOfficeAccess.new(
        agency: agencies(:one),
        actor: staff.user,
        membership: staff,
        office: offices(:one)
      ).call
    end
    assert_equal :unauthorized, error.code
    assert_equal audits, AuditEvent.count
  end

  test "an administrator from another agency cannot mutate offices" do
    agency_memberships(:two).update!(role: "administrator")
    audits = AuditEvent.count

    error = assert_raises(MembershipCommand::Error) do
      CreateOffice.new(
        agency: agencies(:one),
        actor: users(:two),
        name: "Boston",
        code: "BOS"
      ).call
    end

    assert_equal :unauthorized, error.code
    assert_equal audits, AuditEvent.count
  end

  test "mismatched agency and office leave both sides unchanged" do
    snapshot = offices(:two).attributes.slice("name", "status", "code", "lock_version")
    one_audits = agencies(:one).audit_events.count
    two_audits = agencies(:two).audit_events.count

    error = assert_raises(MembershipCommand::Error) do
      UpdateOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        office: offices(:two),
        name: "Forged",
        default_timezone: "UTC"
      ).call
    end

    assert_equal :invalid, error.code
    assert_equal snapshot, offices(:two).reload.attributes.slice("name", "status", "code", "lock_version")
    assert_equal one_audits, agencies(:one).audit_events.count
    assert_equal two_audits, agencies(:two).audit_events.count
  end

  test "mismatched agency and membership leave assignments unchanged" do
    assignment = office_assignments(:two)
    snapshot = assignment.attributes.slice("status", "is_default", "office_id")
    one_audits = agencies(:one).audit_events.count
    two_audits = agencies(:two).audit_events.count

    error = assert_raises(MembershipCommand::Error) do
      GrantOfficeAccess.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:two),
        office: offices(:one)
      ).call
    end

    assert_equal :invalid, error.code
    assert_equal snapshot, assignment.reload.attributes.slice("status", "is_default", "office_id")
    assert_equal one_audits, agencies(:one).audit_events.count
    assert_equal two_audits, agencies(:two).audit_events.count
  end

  test "revoking a default requires a replacement when other assignments remain" do
    extra = create_boston
    GrantOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:one),
      office: extra
    ).call

    error = assert_raises(MembershipCommand::Error) do
      RevokeOfficeAccess.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:one),
        office: offices(:one)
      ).call
    end

    assert_equal :invalid, error.code
    assert office_assignments(:one).reload.active?
    assert office_assignments(:one).is_default?
  end

  test "selecting an office updates only the current session" do
    session = users(:one).sessions.create!
    extra = create_boston

    SelectCurrentOffice.new(session:, office: extra).call

    assert_equal extra.id, session.reload.office_id
    assert_not AuditEvent.exists?(action: "office_access.default_changed", subject_id: extra.id)
  end

  test "deactivating a default office nominates the sole remaining accessible office" do
    extra = create_boston
    session = users(:one).sessions.create!(office: offices(:one))

    ChangeOfficeStatus.new(
      agency: agencies(:one),
      actor: users(:one),
      office: offices(:one),
      to: "inactive",
      reason: "Seasonal close"
    ).call

    assert offices(:one).reload.inactive?
    assert office_assignments(:one).reload.active?
    assert_not office_assignments(:one).is_default?
    assert_equal extra, agency_memberships(:one).reload.default_office
    assert_nil session.reload.office_id
  end

  test "deactivating a default office does not nominate when two offices remain" do
    create_boston
    second = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Chicago",
      code: "CHI",
      default_timezone: agencies(:one).default_timezone
    ).call.office

    ChangeOfficeStatus.new(
      agency: agencies(:one),
      actor: users(:one),
      office: offices(:one),
      to: "inactive",
      reason: "Seasonal close"
    ).call

    assert_nil agency_memberships(:one).reload.default_office
    assert second.reload.active?
    assert office_assignments(:one).reload.active?
  end

  test "reactivating an office does not restore prior defaults" do
    extra = create_boston
    ChangeOfficeStatus.new(
      agency: agencies(:one),
      actor: users(:one),
      office: offices(:one),
      to: "inactive",
      reason: "Seasonal close"
    ).call
    ChangeOfficeStatus.new(
      agency: agencies(:one),
      actor: users(:one),
      office: offices(:one),
      to: "active",
      reason: "Reopened"
    ).call

    assert offices(:one).reload.active?
    assert_equal extra, agency_memberships(:one).reload.default_office
    assert_not office_assignments(:one).reload.is_default?
  end

  private

  def create_boston
    CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
  end

  def invite_and_accept
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "office-staff@example.com",
      role: "staff",
      first_name: "Pat",
      last_name: "Ng",
      **invite_offices
    ).call.membership

    AcceptInvitation.new(
      token: membership.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call.membership
  end
end
