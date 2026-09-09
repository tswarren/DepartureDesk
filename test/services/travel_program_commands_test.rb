require "test_helper"

class TravelProgramCommandsTest < ActiveSupport::TestCase
  test "creates an active program and writes an audit" do
    result = CreateTravelProgram.new(
      agency: agencies(:one),
      actor: users(:staff_one),
      name: "Atlantic Series",
      description: "Internal notes",
      client_facing_description: "Sail the Atlantic"
    ).call

    assert result.travel_program.active?
    assert_equal "Atlantic Series", result.travel_program.name
    assert_equal "travel_program.created", AuditEvent.order(:created_at).last.action
  end

  test "updates name and descriptions only" do
    program = create_travel_program!(agencies(:one), actor: users(:one), name: "Old Name")

    UpdateTravelProgram.new(
      agency: agencies(:one),
      actor: users(:one),
      travel_program: program,
      name: "New Name",
      description: "Updated",
      lock_version: program.lock_version
    ).call

    program.reload
    assert_equal "New Name", program.name
    assert_equal "Updated", program.description
    assert program.active?
    assert_equal "travel_program.updated", AuditEvent.order(:created_at).last.action
  end

  test "staff cannot deactivate a program" do
    program = create_travel_program!(agencies(:one), actor: users(:one))

    error = assert_raises(MembershipCommand::Error) do
      DeactivateTravelProgram.new(
        agency: agencies(:one),
        actor: users(:staff_one),
        travel_program: program,
        reason: "No longer offered"
      ).call
    end

    assert_equal :unauthorized, error.code
    assert program.reload.active?
  end

  test "deactivation conflicts with a nonterminal departure" do
    program = create_travel_program!(agencies(:one), actor: users(:one))
    create_departure!(agencies(:one), actor: users(:one), travel_program: program)

    error = assert_raises(MembershipCommand::Error) do
      DeactivateTravelProgram.new(
        agency: agencies(:one),
        actor: users(:one),
        travel_program: program,
        reason: "No longer offered"
      ).call
    end

    assert_equal :program_dependency, error.code
    assert program.reload.active?
  end

  test "an unused program can be deactivated and reactivated" do
    program = create_travel_program!(agencies(:one), actor: users(:one))

    DeactivateTravelProgram.new(
      agency: agencies(:one),
      actor: users(:one),
      travel_program: program,
      reason: "Paused"
    ).call

    assert program.reload.inactive?
    assert_equal "Paused", program.inactivation_reason

    ReactivateTravelProgram.new(
      agency: agencies(:one),
      actor: users(:one),
      travel_program: program,
      reason: "Offered again"
    ).call

    program.reload
    assert program.active?
    assert_nil program.inactivation_reason
  end

  test "a foreign program cannot be updated" do
    program = create_travel_program!(agencies(:two), actor: users(:two), name: "Pacific")

    error = assert_raises(MembershipCommand::Error) do
      UpdateTravelProgram.new(
        agency: agencies(:one),
        actor: users(:one),
        travel_program: program,
        name: "Forged"
      ).call
    end

    assert_equal :invalid, error.code
    assert_equal "Pacific", program.reload.name
  end
end
