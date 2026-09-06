require "test_helper"

class ClientAdvisorCommandsTest < ActiveSupport::TestCase
  test "assigns changes and clears advisor with history matching the pointer" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    today = DirectoryDate.today(agencies(:one))

    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      membership: agency_memberships(:one)
    ).call
    profile.reload
    assert_equal agency_memberships(:one).id, profile.primary_advisor_membership_id
    assert_equal "active", profile.primary_advisor_membership_status
    first = profile.open_advisor_assignment
    assert_equal agency_memberships(:one).id, first.advisor_membership_id
    assert_equal today, first.effective_from
    assert_nil first.effective_until
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_advisor_assigned"

    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      membership: agency_memberships(:staff_one)
    ).call
    profile.reload
    assert_equal agency_memberships(:staff_one).id, profile.primary_advisor_membership_id
    first.reload
    assert_equal today, first.effective_until
    current = profile.open_advisor_assignment
    assert_equal agency_memberships(:staff_one).id, current.advisor_membership_id
    assert_equal today, current.effective_from
    assert_nil current.effective_until
    assert_equal 1, ClientAdvisorAssignment.current_on(today).where(client_profile: profile).count
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_advisor_reassigned"

    ClearClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:
    ).call
    profile.reload
    assert_nil profile.primary_advisor_membership_id
    assert_nil profile.primary_advisor_membership_status
    assert_nil profile.open_advisor_assignment
    current.reload
    assert_equal today, current.effective_until
    assert_includes agencies(:one).audit_events.pluck(:action), "directory.client_advisor_cleared"
  end

  test "invited memberships are not assignable" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    invited = InviteTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      email: "invited.advisor@example.com",
      role: "staff",
      first_name: "Invited",
      last_name: "Advisor",
      **invite_offices
    ).call.membership

    error = assert_raises(MembershipCommand::Error) do
      AssignClientAdvisor.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        membership: invited
      ).call
    end

    assert_equal :invalid, error.code
    assert_match(/active team member/i, error.message)
    assert_nil profile.reload.primary_advisor_membership_id
  end

  test "deactivating a client clears the advisor and reactivation does not restore it" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      membership: agency_memberships(:staff_one)
    ).call

    DeactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      reason: "No longer purchasing"
    ).call
    profile.reload
    assert profile.inactive?
    assert_nil profile.primary_advisor_membership_id
    assert_nil profile.primary_advisor_membership_status
    assert_nil profile.open_advisor_assignment
    ended = profile.advisor_assignments.order(:effective_from, :id).last
    assert_equal "No longer purchasing", ended.ending_reason

    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office
    ReactivateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      office: extra
    ).call
    profile.reload
    assert profile.active?
    assert_nil profile.primary_advisor_membership_id
    assert_nil profile.open_advisor_assignment
  end

  test "UpdateClientProfile cannot change status or identity" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    party_id = profile.party_id

    UpdateClientProfile.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      office: offices(:one),
      communication_preference: "email",
      servicing_restrictions: "Call before mailing invoices.",
      billing_restrictions: "No weekend billing."
    ).call
    profile.reload
    assert profile.active?
    assert_equal "email", profile.communication_preference
    assert_equal "Call before mailing invoices.", profile.servicing_restrictions
    assert_equal "No weekend billing.", profile.billing_restrictions
    assert_equal party_id, profile.party_id
    assert_equal "person", profile.party_kind
    event = agencies(:one).audit_events.where(action: "directory.client_profile_updated").order(:created_at).last
    assert_equal [ "communication_preference", "servicing_restrictions", "billing_restrictions" ], event.details["changed_fields"]
    assert_not_includes event.details.to_s, "Call before mailing"
    assert_not_includes event.details.to_s, "No weekend billing"
  end

  test "UpdateClientProfile screens restriction text" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      UpdateClientProfile.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        office: offices(:one),
        servicing_restrictions: "password: hunter2"
      ).call
    end

    assert_equal :invalid, error.code
    assert_nil profile.reload.servicing_restrictions
  end

  test "SuspendMembership is blocked while the membership is a current advisor" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      membership: agency_memberships(:staff_one)
    ).call

    error = assert_raises(MembershipCommand::Error) do
      SuspendMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:staff_one)
      ).call
    end

    assert_equal :advisor_dependency, error.code
    assert_match(/\AReassign 1 current client before suspending this membership: Alex Morgan\.\z/, error.message)
    assert agency_memberships(:staff_one).reload.active?
    assert_equal agency_memberships(:staff_one).id, profile.reload.primary_advisor_membership_id
  end

  test "SuspendMembership names a bounded sample of advised clients" do
    [
      parties(:unlinked),
      parties(:organization_one),
      parties(:household_one),
      parties(:maria),
      parties(:harbor_hotel),
      parties(:harbor_group)
    ].each do |party|
      profile = assign_client_role!(party, actor: users(:one))
      AssignClientAdvisor.new(
        agency: agencies(:one),
        actor: users(:one),
        party:,
        profile:,
        membership: agency_memberships(:staff_one)
      ).call
    end

    error = assert_raises(MembershipCommand::Error) do
      SuspendMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:staff_one)
      ).call
    end

    assert_equal :advisor_dependency, error.code
    assert_match(/\AReassign 6 current clients before suspending this membership: /, error.message)
    assert_includes error.message, "Alex Morgan"
    assert_includes error.message, "Horizon Tours"
    assert_includes error.message, "Morgan Household"
    assert_includes error.message, "Maria Ruiz"
    assert_includes error.message, "Harbor Hotel Boston"
    assert_not_includes error.message, "Harbor Hospitality Group"
    assert_match(/, and 1 more\.\z/, error.message)
    assert agency_memberships(:staff_one).reload.active?
  end

  test "clearing the advisor allows suspension and reactivation does not restore it" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:one))
    AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:,
      membership: agency_memberships(:staff_one)
    ).call
    ClearClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:one),
      party:,
      profile:
    ).call

    SuspendMembership.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:staff_one)
    ).call
    assert agency_memberships(:staff_one).reload.suspended?
    assert_nil profile.reload.primary_advisor_membership_id

    ReactivateMembership.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:staff_one)
    ).call
    assert agency_memberships(:staff_one).reload.active?
    assert_nil profile.reload.primary_advisor_membership_id
  end

  test "staff can assign an advisor" do
    party = parties(:unlinked)
    profile = assign_client_role!(party, actor: users(:staff_one))

    result = AssignClientAdvisor.new(
      agency: agencies(:one),
      actor: users(:staff_one),
      party:,
      profile:,
      membership: agency_memberships(:one)
    ).call

    assert result.ok?
    assert_equal agency_memberships(:one).id, profile.reload.primary_advisor_membership_id
  end
end
