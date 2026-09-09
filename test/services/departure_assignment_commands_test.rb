require "test_helper"

class DepartureAssignmentCommandsTest < ActiveSupport::TestCase
  test "assigning a team role rejects when a current assignment exists" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      AssignDepartureTeamMember.new(
        agency: agencies(:one),
        actor: users(:one),
        departure:,
        membership: agency_memberships(:staff_one),
        role: "group_manager"
      ).call
    end

    assert_equal :conflict, error.code
    assert_match(/Replace/, error.message)
  end

  test "ordinary staff cannot take over management" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      ReplaceDepartureTeamMember.new(
        agency: agencies(:one),
        actor: users(:staff_one),
        departure:,
        role: "group_manager",
        membership: agency_memberships(:staff_one),
        reason: "Taking over"
      ).call
    end

    assert_equal :unauthorized, error.code
    assert_equal agency_memberships(:one).id, departure.reload.current_group_manager_assignment.agency_membership_id
  end

  test "replacing a manager keeps a continuous current assignment" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    original = departure.current_group_manager_assignment

    ReplaceDepartureTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      role: "group_manager",
      membership: agency_memberships(:staff_one),
      reason: "Coverage"
    ).call

    departure.reload
    assert_not original.reload.current?
    assert_equal "Coverage", original.ending_reason
    assert_equal agency_memberships(:staff_one).id, departure.current_group_manager_assignment.agency_membership_id
    assert_equal 1, departure.team_assignments.current.group_manager.count
  end

  test "ending the sole manager is rejected" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      EndDepartureTeamAssignment.new(
        agency: agencies(:one),
        actor: users(:one),
        departure:,
        assignment: departure.current_group_manager_assignment,
        reason: "Stepping down"
      ).call
    end

    assert_equal :invalid_state, error.code
    assert departure.reload.current_group_manager_assignment.current?
  end

  test "an advisor can be assigned and ended" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    AssignDepartureTeamMember.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      membership: agency_memberships(:staff_one),
      role: "responsible_advisor"
    ).call

    assignment = departure.reload.current_responsible_advisor_assignment
    EndDepartureTeamAssignment.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      assignment:,
      reason: "No longer advising"
    ).call

    assert_nil departure.reload.current_responsible_advisor_assignment
    assert_not assignment.reload.current?
  end

  test "first party role is primary and later roles default nonprimary" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    first = AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:unlinked),
      role: "organizer"
    ).call.assignment
    second = AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:organization_one),
      role: "organizer"
    ).call.assignment

    assert first.reload.is_primary?
    assert_not second.reload.is_primary?
  end

  test "ending the primary requires a replacement" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    first = AssignDeparturePartyRole.new(agency: agencies(:one), actor: users(:one), departure:, party: parties(:unlinked), role: "sponsor").call.assignment
    second = AssignDeparturePartyRole.new(agency: agencies(:one), actor: users(:one), departure:, party: parties(:organization_one), role: "sponsor").call.assignment

    error = assert_raises(MembershipCommand::Error) do
      EndDeparturePartyRole.new(
        agency: agencies(:one),
        actor: users(:one),
        departure:,
        assignment: first,
        reason: "Ended"
      ).call
    end
    assert_equal :invalid, error.code

    EndDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      assignment: first,
      replacement: second,
      reason: "Ended"
    ).call

    assert_not first.reload.current?
    assert second.reload.is_primary?
  end

  test "group leader must be a person" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      AssignDeparturePartyRole.new(
        agency: agencies(:one),
        actor: users(:one),
        departure:,
        party: parties(:organization_one),
        role: "group_leader"
      ).call
    end

    assert_equal :invalid, error.code
  end

  test "current party roles on a nonterminal departure block deactivation" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:unlinked),
      role: "organizer"
    ).call

    error = assert_raises(MembershipCommand::Error) do
      DeactivateParty.new(agency: agencies(:one), actor: users(:one), party: parties(:unlinked), reason: "Cleanup").call
    end

    assert_equal :party_dependency, error.code
    assert_match(/D-/, error.message)
  end
end
