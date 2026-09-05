require "test_helper"

class RecoverAgencyAdministratorTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "replaces an invited administrator invitation" do
    provisioned = provision_agency
    membership = provisioned.membership
    old_token = membership.invitation_token

    assert_enqueued_with(job: DeliveryIntentJob) do
      RecoverAgencyAdministrator.new(
        agency: provisioned.agency,
        actor_identifier: "ops:recovery",
        reason: "Expired invitation",
        mode: "replace_invitation",
        membership: membership
      ).call
    end

    membership.reload
    assert membership.invited?
    assert_nil AgencyMembership.find_by_token_for(:invitation, old_token)
    assert AgencyMembership.find_by_token_for(:invitation, membership.invitation_token)

    actions = provisioned.agency.audit_events.order(:created_at).pluck(:action)
    assert_includes actions, "team.administrator_recovery_started"
    assert_includes actions, "team.invitation_replaced"
    event = provisioned.agency.audit_events.find_by!(action: "team.administrator_recovery_started")
    assert_equal "system", event.actor_kind
    assert_equal "ops:recovery", event.actor_identifier
    assert_nil event.actor_user_id
  end

  test "reactivates a suspended administrator" do
    agency = agencies(:one)
    extra = invite_and_activate_admin
    SuspendMembership.new(agency: agency, actor: users(:one), membership: extra).call

    RecoverAgencyAdministrator.new(
      agency: agency,
      actor_identifier: "ops:recovery",
      reason: "Restore access",
      mode: "reactivate",
      membership: extra
    ).call

    assert extra.reload.active?
    assert extra.user.reload.usable_agency_membership
    assert_equal %w[team.administrator_recovery_started team.membership_reactivated],
      agency.audit_events.where(action: %w[team.administrator_recovery_started team.membership_reactivated]).order(:created_at).pluck(:action)
  end

  test "invites a replacement administrator when none is usable" do
    provisioned = provision_agency
    RevokeInvitation.new(
      agency: provisioned.agency,
      actor_identifier: "ops:recovery",
      privileged: true,
      membership: provisioned.membership
    ).call

    result = nil
    assert_enqueued_with(job: DeliveryIntentJob) do
      result = RecoverAgencyAdministrator.new(
        agency: provisioned.agency,
        actor_identifier: "ops:recovery",
        reason: "No usable administrator",
        mode: "invite_replacement",
        email: "replacement-admin@example.com",
        first_name: "Quinn",
        last_name: "Hale"
      ).call
    end

    assert result.membership.invited?
    assert result.membership.administrator?
    assert_equal "replacement-admin@example.com", result.membership.user.email_address
  end

  test "does not attach an address that is active elsewhere" do
    provisioned = provision_agency

    assert_no_difference("AgencyMembership.count") do
      error = assert_raises(RecoverAgencyAdministrator::Error) do
        RecoverAgencyAdministrator.new(
          agency: provisioned.agency,
          actor_identifier: "ops:recovery",
          reason: "Need another admin",
          mode: "invite_replacement",
          email: users(:one).email_address,
          first_name: "Jordan",
          last_name: "Blake"
        ).call
      end
      assert_equal :conflict, error.code
    end

    assert_not provisioned.agency.audit_events.exists?(action: "team.administrator_recovery_started")
  end

  test "does not reactivate a suspended agency" do
    agency = agencies(:one)
    ChangeAgencyStatus.new(
      agency: agency,
      to: "suspended",
      reason: "Pause",
      actor_identifier: "ops:lifecycle"
    ).call

    assert_no_difference -> { agency.audit_events.count } do
      error = assert_raises(RecoverAgencyAdministrator::Error) do
        RecoverAgencyAdministrator.new(
          agency: agency.reload,
          actor_identifier: "ops:recovery",
          reason: "Need admin",
          mode: "replace_invitation",
          membership: agency_memberships(:one)
        ).call
      end
      assert_equal :invalid_state, error.code
    end

    assert agency.reload.suspended?
  end

  test "failed recovery writes no success audit" do
    provisioned = provision_agency
    before = provisioned.agency.audit_events.count

    assert_raises(RecoverAgencyAdministrator::Error) do
      RecoverAgencyAdministrator.new(
        agency: provisioned.agency,
        actor_identifier: "ops:recovery",
        reason: "Wrong mode",
        mode: "not-a-mode",
        membership: provisioned.membership
      ).call
    end

    assert_equal before, provisioned.agency.reload.audit_events.count
  end

  private

  def provision_agency
    ProvisionAgency.new(
      idempotency_key: SecureRandom.hex(8),
      actor_identifier: "ops:test",
      name: "Recovery #{SecureRandom.hex(4)}",
      email: "recovery-#{SecureRandom.hex(4)}@example.com",
      first_name: "Morgan",
      last_name: "Lee"
    ).call
  end

  def invite_and_activate_admin
    membership = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "second-admin@example.com",
      role: "administrator",
      first_name: "Reese",
      last_name: "Patel"
    ).call.membership

    AcceptInvitation.new(
      token: membership.invitation_token,
      password: "Newpass123!",
      password_confirmation: "Newpass123!"
    ).call.membership
  end
end
