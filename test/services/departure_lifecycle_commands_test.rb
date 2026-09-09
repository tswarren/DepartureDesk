require "test_helper"

class DepartureLifecycleCommandsTest < ActiveSupport::TestCase
  test "cancellation ends assignments and nulls projections" do
    program = create_travel_program!(agencies(:one), actor: users(:one))
    departure = create_departure!(agencies(:one), actor: users(:one), travel_program: program)
    AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:unlinked),
      role: "organizer"
    ).call

    CancelDeparture.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      reason: "Group withdrew"
    ).call

    departure.reload
    assert departure.cancelled?
    assert_nil departure.owning_office_status
    assert_nil departure.travel_program_status
    assert_equal program.id, departure.travel_program_id
    assert_equal offices(:one).id, departure.office_id
    assert_equal 0, departure.team_assignments.current.count
    assert_equal 0, departure.party_role_assignments.current.count
    assert_equal "departure.cancelled", AuditEvent.order(:created_at).last.action
  end

  test "ordinary staff cannot cancel" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      CancelDeparture.new(
        agency: agencies(:one),
        actor: users(:staff_one),
        departure:,
        reason: "Trying"
      ).call
    end

    assert_equal :unauthorized, error.code
    assert departure.reload.draft?
  end

  test "office transfer keeps the reference and assignment dates" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: "America/New_York"
    ).call.office
    GrantOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:one),
      office: extra
    ).call
    departure = create_departure!(agencies(:one), actor: users(:one))
    original_from = departure.current_group_manager_assignment.effective_from
    reference = departure.departure_reference

    TransferDepartureOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      office: extra
    ).call

    departure.reload
    assert_equal extra.id, departure.office_id
    assert_equal "active", departure.owning_office_status
    assert_equal reference, departure.departure_reference
    assert_equal original_from, departure.current_group_manager_assignment.effective_from
  end

  test "office transfer rejects assignees who cannot access the destination" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: "America/New_York"
    ).call.office
    departure = create_departure!(
      agencies(:one),
      actor: users(:one),
      responsible_advisor_membership: agency_memberships(:staff_one)
    )

    error = assert_raises(MembershipCommand::Error) do
      TransferDepartureOffice.new(
        agency: agencies(:one),
        actor: users(:one),
        departure:,
        office: extra
      ).call
    end

    assert_equal :office_access_dependency, error.code
    assert_equal offices(:one).id, departure.reload.office_id
  end

  test "staff cannot transfer offices" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: "America/New_York"
    ).call.office
    departure = create_departure!(agencies(:one), actor: users(:staff_one))

    error = assert_raises(MembershipCommand::Error) do
      TransferDepartureOffice.new(
        agency: agencies(:one),
        actor: users(:staff_one),
        departure:,
        office: extra
      ).call
    end

    assert_equal :unauthorized, error.code
  end

  test "office deactivation conflicts with a nonterminal departure" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: "America/New_York"
    ).call.office
    GrantOfficeAccess.new(
      agency: agencies(:one),
      actor: users(:one),
      membership: agency_memberships(:one),
      office: extra
    ).call
    create_departure!(agencies(:one), actor: users(:one), office: extra)

    error = assert_raises(MembershipCommand::Error) do
      ChangeOfficeStatus.new(
        agency: agencies(:one),
        actor: users(:one),
        office: extra,
        to: "inactive",
        reason: "Closing"
      ).call
    end

    assert_equal :departure_dependency, error.code
    assert extra.reload.active?
  end

  test "membership suspension conflicts with a current departure assignment" do
    create_departure!(agencies(:one), actor: users(:one), group_manager_membership: agency_memberships(:staff_one))

    error = assert_raises(MembershipCommand::Error) do
      SuspendMembership.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:staff_one)
      ).call
    end

    assert_equal :departure_dependency, error.code
    assert agency_memberships(:staff_one).reload.active?
  end

  test "revoking staff office access conflicts with a current assignment there" do
    create_departure!(agencies(:one), actor: users(:one), group_manager_membership: agency_memberships(:staff_one))

    error = assert_raises(MembershipCommand::Error) do
      RevokeOfficeAccess.new(
        agency: agencies(:one),
        actor: users(:one),
        membership: agency_memberships(:staff_one),
        office: offices(:one)
      ).call
    end

    assert_equal :departure_dependency, error.code
  end

  test "a cancelled departure no longer blocks party deactivation" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    AssignDeparturePartyRole.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      party: parties(:unlinked),
      role: "organizer"
    ).call
    CancelDeparture.new(agency: agencies(:one), actor: users(:one), departure:, reason: "Withdrawn").call

    DeactivateParty.new(agency: agencies(:one), actor: users(:one), party: parties(:unlinked), reason: "Cleanup").call

    assert parties(:unlinked).reload.deactivated?
  end
end
