require "test_helper"

class ChangeAgencyStatusTest < ActiveSupport::TestCase
  test "suspends an agency and records a system audit" do
    agency = agencies(:one)
    own_session = users(:one).sessions.create!
    other_session = users(:two).sessions.create!

    ChangeAgencyStatus.new(
      agency: agency,
      to: "suspended",
      reason: "Contract review",
      actor_identifier: "ops:lifecycle"
    ).call

    agency.reload
    assert agency.suspended?
    assert_not Session.exists?(own_session.id)
    assert Session.exists?(other_session.id)

    event = agency.audit_events.order(:created_at).last
    assert_equal "agency.suspended", event.action
    assert_equal "system", event.actor_kind
    assert_equal "ops:lifecycle", event.actor_identifier
    assert_nil event.actor_user_id
    assert_equal "Contract review", event.details["reason"]
  end

  test "reactivation does not unsuspend memberships or require session destruction" do
    agency = agencies(:one)
    staff = invite_and_activate_staff
    SuspendMembership.new(agency: agency, actor: users(:one), membership: staff).call
    ChangeAgencyStatus.new(
      agency: agency,
      to: "suspended",
      reason: "Pause operations",
      actor_identifier: "ops:lifecycle"
    ).call

    ChangeAgencyStatus.new(
      agency: agency,
      to: "active",
      reason: "Resume operations",
      actor_identifier: "ops:lifecycle"
    ).call

    assert agency.reload.active?
    assert staff.reload.suspended?
    assert_equal "agency.reactivated", agency.audit_events.order(:created_at).last.action
  end

  test "closed is terminal and does not delete tenant data" do
    agency = agencies(:one)
    membership_id = agency_memberships(:one).id

    ChangeAgencyStatus.new(
      agency: agency,
      to: "closed",
      reason: "Agency wound down",
      actor_identifier: "ops:lifecycle"
    ).call

    assert agency.reload.closed?
    assert Agency.exists?(agency.id)
    assert AgencyMembership.exists?(membership_id)
    assert_nil users(:one).reload.usable_agency_membership

    error = assert_raises(ChangeAgencyStatus::Error) do
      ChangeAgencyStatus.new(
        agency: agency,
        to: "active",
        reason: "Reopen",
        actor_identifier: "ops:lifecycle"
      ).call
    end

    assert_equal :invalid_state, error.code
    assert agency.reload.closed?
  end

  test "requires a reason" do
    assert_no_changes -> { agencies(:one).reload.status } do
      error = assert_raises(ChangeAgencyStatus::Error) do
        ChangeAgencyStatus.new(
          agency: agencies(:one),
          to: "suspended",
          reason: " ",
          actor_identifier: "ops:lifecycle"
        ).call
      end
      assert_equal :invalid, error.code
    end
  end

  test "serializes conflicting status changes" do
    agency = agencies(:one)
    ChangeAgencyStatus.new(
      agency: agency,
      to: "suspended",
      reason: "First change",
      actor_identifier: "ops:lifecycle"
    ).call

    error = assert_raises(ChangeAgencyStatus::Error) do
      ChangeAgencyStatus.new(
        agency: agency.reload,
        to: "suspended",
        reason: "Second change",
        actor_identifier: "ops:lifecycle"
      ).call
    end

    assert_equal :invalid_state, error.code
    assert_equal 1, agency.audit_events.where(action: "agency.suspended").count
  end

  private

  def invite_and_activate_staff
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "status-staff@example.com",
      role: "staff",
      first_name: "Sam",
      last_name: "River",
      **invite_offices
    ).call.membership

    AcceptInvitation.new(
      token: membership.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call.membership
  end
end
