require "test_helper"

class M2aDepartureConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M2A Race #{suffix}",
      workspace_code: "r#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race",
      administrator_last_name: "Admin",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m2a-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @office = @agency.offices.sole
  end

  teardown do
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "two different departures activate concurrently with distinct references" do
    first = complete_draft("Race One")
    second = complete_draft("Race Two")
    outcomes = race(2) do |index|
      departure = index.zero? ? first : second
      ActivateDeparture.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        departure: Departure.find(departure.id),
        lock_version: departure.lock_version
      ).call
    end

    created = outcomes.grep(AgencyCommand::Result)
    assert_equal 2, created.size
    references = created.map { |result| result.record.departure_reference }
    assert_equal 2, references.uniq.size
  end

  test "the same departure activated twice yields one transition, reference, and audit" do
    departure = complete_draft("Double Activate")
    outcomes = race(2) do
      ActivateDeparture.new(
        agency: Agency.find(@agency.id),
        actor: AgencyUser.find(@actor.id),
        departure: Departure.find(departure.id),
        lock_version: departure.lock_version
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal 2, results.size
    assert_equal %i[noop updated].sort, results.map(&:status).sort
    assert_equal 1, results.map { |result| result.record.departure_reference }.uniq.size
    assert_equal 1, @agency.departures.where(id: departure.id, status: "active").count
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "departure.activated", subject_id: departure.id).count
  end

  test "create versus agency suspension rechecks the locked agency" do
    outcomes = race(2, allowed_error_codes: %i[invalid_state]) do |index|
      if index.zero?
        CreateDeparture.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          attributes: { name: "Late Create" }
        ).call
      else
        ChangeAgencyStatus.new(
          agency: Agency.find(@agency.id),
          status: "suspended",
          actor_identifier: "test:m2a-suspend"
        ).call
      end
    end

    @agency.reload
    created = @agency.departures.where(name: "Late Create")
    if created.exists?
      assert_equal "suspended", @agency.status
      assert_equal 1, created.count
    else
      assert_equal "suspended", @agency.status
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid_state
    end
  end

  test "activation versus office inactivation leaves a valid outcome" do
    departure = complete_draft("Office Race")
    outcomes = race(2, allowed_error_codes: %i[invalid_state conflict]) do |index|
      if index.zero?
        ActivateDeparture.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: Departure.find(departure.id),
          lock_version: departure.lock_version
        ).call
      else
        ChangeOfficeStatus.new(
          office: Office.find(@office.id),
          actor: AgencyUser.find(@actor.id),
          status: "inactive",
          lock_version: @office.lock_version
        ).call
      end
    end

    departure.reload
    @office.reload
    if departure.active?
      assert_equal "D-000001", departure.departure_reference
      assert_includes %w[active inactive], @office.status
    else
      assert_equal "draft", departure.status
      assert_nil departure.departure_reference
      assert_equal "inactive", @office.status
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid_state
    end
  end

  test "activation versus agency user suspension leaves a valid outcome" do
    staff = @agency.agency_users.create!(
      email_address: "staff-#{SecureRandom.hex(3)}@example.test",
      first_name: "Staff",
      last_name: "Racer",
      password: TEST_PASSWORD,
      access_role: "staff",
      status: "active",
      default_office: @office,
      credential_version: 1
    )
    departure = complete_draft("User Race", responsible_agency_user_id: staff.id)
    outcomes = race(2, allowed_error_codes: %i[invalid_state conflict last_administrator]) do |index|
      if index.zero?
        ActivateDeparture.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: Departure.find(departure.id),
          lock_version: departure.lock_version
        ).call
      else
        ChangeAgencyUserAccess.new(
          agency_user: AgencyUser.find(staff.id),
          actor: AgencyUser.find(@actor.id),
          status: "suspended",
          lock_version: staff.lock_version
        ).call
      end
    end

    departure.reload
    if departure.active?
      assert_equal "D-000001", departure.departure_reference
    else
      assert_equal "draft", departure.status
      assert_nil departure.departure_reference
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid_state
    end
  end

  test "activation versus ordinary edit does not lose the update" do
    departure = complete_draft("Edit Race")
    outcomes = race(2, allowed_error_codes: %i[conflict]) do |index|
      record = Departure.find(departure.id)
      if index.zero?
        ActivateDeparture.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: record,
          lock_version: departure.lock_version
        ).call
      else
        UpdateDeparture.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: record,
          attributes: {
            name: "Edited Race",
            description: record.description,
            starts_on: record.starts_on,
            ends_on: record.ends_on,
            time_zone: record.time_zone,
            operating_currency: record.operating_currency
          },
          lock_version: departure.lock_version
        ).call
      end
    end

    results = outcomes.grep(AgencyCommand::Result)
    errors = outcomes.grep(AgencyCommand::Error)
    assert_equal 1, results.size
    assert_equal 1, errors.size
    assert_equal :conflict, errors.first.code
    departure.reload
    assert_includes [ "Edit Race", "Edited Race" ], departure.name
  end

  test "responsibility reassignment versus target inactivation leaves a valid outcome" do
    other_office = @agency.offices.create!(name: "Second Office", code: "SEC", default_timezone: "UTC", status: "active")
    departure = complete_draft("Responsibility Race")
    outcomes = race(2, allowed_error_codes: %i[invalid_state conflict]) do |index|
      if index.zero?
        UpdateDepartureResponsibility.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: Departure.find(departure.id),
          office_id: other_office.id,
          agency_user_id: @actor.id,
          lock_version: departure.lock_version
        ).call
      else
        ChangeOfficeStatus.new(
          office: Office.find(other_office.id),
          actor: AgencyUser.find(@actor.id),
          status: "inactive",
          lock_version: other_office.lock_version
        ).call
      end
    end

    departure.reload
    other_office.reload
    if departure.responsible_office_id == other_office.id
      assert_equal other_office.id, departure.responsible_office_id
    else
      assert_equal @office.id, departure.responsible_office_id
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid_state
    end
  end

  private

  def complete_draft(name, **overrides)
    CreateDeparture.new(
      agency: @agency,
      actor: @actor,
      attributes: {
        name:,
        starts_on: Date.new(2026, 8, 1),
        ends_on: Date.new(2026, 8, 8),
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @actor.id
      }.merge(overrides)
    ).call.record
  end

  def race(count, allowed_error_codes: [])
    ready = Queue.new
    release = Queue.new
    threads = count.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          yield index
        end
      rescue StandardError => error
        error
      end
    end
    count.times { ready.pop }
    count.times { release << true }
    outcomes = threads.map(&:value)
    outcomes.each { |outcome| assert_expected_race_outcome!(outcome, allowed_error_codes:) }
    outcomes
  end

  def assert_expected_race_outcome!(outcome, allowed_error_codes:)
    return if outcome.is_a?(AgencyCommand::Result)
    return if outcome.is_a?(AgencyCommand::Error) && allowed_error_codes.include?(outcome.code)

    raise outcome if outcome.is_a?(Exception)

    flunk "unexpected race outcome: #{outcome.inspect}"
  end
end
