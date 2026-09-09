require "test_helper"

class DepartureCommandsTest < ActiveSupport::TestCase
  test "creates a draft departure with a manager, reference, and audit" do
    result = CreateDeparture.new(
      agency: agencies(:one),
      actor: users(:one),
      office: offices(:one),
      name: "Smith Family Reunion Cruise",
      start_date: Date.new(2027, 7, 12),
      end_date: Date.new(2027, 7, 19),
      creation_idempotency_key: SecureRandom.uuid
    ).call

    departure = result.departure
    assert departure.draft?
    assert_match(/\AD-\d{6,}\z/, departure.departure_reference)
    assert_equal "USD", departure.default_currency
    assert_equal "active", departure.owning_office_status
    assert_equal agency_memberships(:one).id, departure.current_group_manager_assignment.agency_membership_id
    assert_nil departure.current_responsible_advisor_assignment
    assert_equal 0, departure.party_role_assignments.count
    assert_equal "departure.created", AuditEvent.order(:created_at).last.action
  end

  test "create can include an optional advisor and never creates party roles" do
    departure = create_departure!(
      agencies(:one),
      actor: users(:one),
      responsible_advisor_membership: agency_memberships(:staff_one)
    )

    assert_equal agency_memberships(:staff_one).id, departure.current_responsible_advisor_assignment.agency_membership_id
    assert_equal 0, departure.party_role_assignments.count
  end

  test "same-key retry returns the original departure without consuming another reference" do
    key = SecureRandom.uuid
    first = create_departure!(agencies(:one), actor: users(:one), name: "Repeatable", creation_idempotency_key: key)
    second = CreateDeparture.new(
      agency: agencies(:one),
      actor: users(:one),
      office: offices(:one),
      name: "Repeatable",
      start_date: first.start_date,
      end_date: first.end_date,
      creation_idempotency_key: key
    ).call.departure

    assert_equal first.id, second.id
    assert_equal first.departure_reference, second.departure_reference
    assert_equal 1, agencies(:one).departures.count
  end

  test "same-key conflicting retry fails without consuming another reference" do
    key = SecureRandom.uuid
    first = create_departure!(agencies(:one), actor: users(:one), name: "Original", creation_idempotency_key: key)

    error = assert_raises(MembershipCommand::Error) do
      CreateDeparture.new(
        agency: agencies(:one),
        actor: users(:one),
        office: offices(:one),
        name: "Different",
        start_date: first.start_date,
        end_date: first.end_date,
        creation_idempotency_key: key
      ).call
    end

    assert_equal :idempotency_conflict, error.code
    assert_equal 1, agencies(:one).departures.count
  end

  test "staff cannot create a departure in an inaccessible office" do
    extra = CreateOffice.new(
      agency: agencies(:one),
      actor: users(:one),
      name: "Boston",
      code: "BOS",
      default_timezone: agencies(:one).default_timezone
    ).call.office

    error = assert_raises(MembershipCommand::Error) do
      create_departure!(agencies(:one), actor: users(:staff_one), office: extra)
    end

    assert_equal :not_found, error.code
    assert_equal 0, agencies(:one).departures.count
  end

  test "updates editable fields and maintains the program projection" do
    program = create_travel_program!(agencies(:one), actor: users(:one))
    departure = create_departure!(agencies(:one), actor: users(:one))

    UpdateDeparture.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      name: "Updated Name",
      start_date: departure.start_date,
      end_date: departure.end_date,
      default_currency: "CAD",
      travel_program: program,
      lock_version: departure.lock_version
    ).call

    departure.reload
    assert_equal "Updated Name", departure.name
    assert_equal "CAD", departure.default_currency
    assert_equal program.id, departure.travel_program_id
    assert_equal "active", departure.travel_program_status
    assert departure.draft?
  end

  test "operator input cannot override the reference" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    reference = departure.departure_reference

    UpdateDeparture.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      name: "Still Original Reference",
      start_date: departure.start_date,
      end_date: departure.end_date,
      default_currency: departure.default_currency,
      lock_version: departure.lock_version
    ).call

    assert_equal reference, departure.reload.departure_reference
  end

  test "start planning moves draft to planning" do
    departure = create_departure!(agencies(:one), actor: users(:one))

    StartDeparturePlanning.new(
      agency: agencies(:one),
      actor: users(:one),
      departure:,
      lock_version: departure.lock_version
    ).call

    assert departure.reload.planning?
    assert_equal "departure.planning_started", AuditEvent.order(:created_at).last.action
  end

  test "planning cannot start twice" do
    departure = create_departure!(agencies(:one), actor: users(:one))
    StartDeparturePlanning.new(agency: agencies(:one), actor: users(:one), departure:).call

    error = assert_raises(MembershipCommand::Error) do
      StartDeparturePlanning.new(agency: agencies(:one), actor: users(:one), departure: departure.reload).call
    end

    assert_equal :invalid_state, error.code
  end

  test "a foreign departure cannot be updated" do
    departure = create_departure!(agencies(:two), actor: users(:two))

    error = assert_raises(MembershipCommand::Error) do
      UpdateDeparture.new(
        agency: agencies(:one),
        actor: users(:one),
        departure:,
        name: "Forged",
        start_date: departure.start_date,
        end_date: departure.end_date
      ).call
    end

    assert_equal :invalid, error.code
  end

  test "unknown audit subjects remain rejected" do
    error = assert_raises(ArgumentError) do
      RecordAdministrativeAudit.record(
        agency: agencies(:one),
        action: "departure.created",
        actor_user: users(:one),
        subject: users(:one)
      )
    end
    assert_match(/Unknown audit subject type/, error.message)
  end
end
