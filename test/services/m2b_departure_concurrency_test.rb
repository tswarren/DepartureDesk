require "test_helper"

class M2bDepartureConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M2B Race #{suffix}",
      workspace_code: "b#{suffix}",
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
      actor_identifier: "test:m2b-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @office = @agency.offices.sole
  end

  teardown do
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "return to draft versus departed leaves exactly one lifecycle outcome" do
    departure = eligible_active("Draft Or Departed")
    outcomes = race(2, allowed_error_codes: %i[invalid_state conflict]) do |index|
      record = Departure.find(departure.id)
      if index.zero?
        ReturnDepartureToDraft.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: record,
          reason: "Hold the sailing",
          lock_version: departure.lock_version
        ).call
      else
        MarkDepartureDeparted.new(
          agency: Agency.find(@agency.id),
          departure: record,
          actor_kind: :agency_user,
          actor: AgencyUser.find(@actor.id),
          lock_version: departure.lock_version
        ).call
      end
    end

    departure.reload
    assert_includes %w[draft departed], departure.status
    assert_equal "D-000001", departure.departure_reference
    if departure.departed?
      assert_not_nil departure.departed_at
      assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "departure.departed", subject_id: departure.id).count
      assert_equal 0, AuditEvent.where(agency_id: @agency.id, action: "departure.returned_to_draft", subject_id: departure.id).count
    else
      assert_nil departure.departed_at
      assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "departure.returned_to_draft", subject_id: departure.id).count
      assert_equal 0, AuditEvent.where(agency_id: @agency.id, action: "departure.departed", subject_id: departure.id).count
    end
    assert outcomes.grep(AgencyCommand::Result).any?
  end

  test "job versus manual departed yields one updated, one noop, and one audit" do
    departure = eligible_active("Job And Manual")
    outcomes = race(2) do |index|
      record = Departure.find(departure.id)
      if index.zero?
        MarkDepartureDeparted.new(
          agency: Agency.find(@agency.id),
          departure: record,
          actor_kind: :agency_user,
          actor: AgencyUser.find(@actor.id),
          lock_version: departure.lock_version
        ).call
      else
        MarkDepartureDeparted.new(
          agency: Agency.find(@agency.id),
          departure: record,
          actor_kind: :system,
          actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER
        ).call
      end
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal 2, results.size
    assert_equal %i[noop updated].sort, results.map(&:status).sort
    departure.reload
    assert_equal "departed", departure.status
    assert_not_nil departure.departed_at
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "departure.departed", subject_id: departure.id).count
  end

  test "two jobs for the same departure yield one updated and one noop" do
    departure = eligible_active("Two Jobs")
    outcomes = race(2) do
      MarkDepartureDeparted.new(
        agency: Agency.find(@agency.id),
        departure: Departure.find(departure.id),
        actor_kind: :system,
        actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER
      ).call
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal 2, results.size
    assert_equal %i[noop updated].sort, results.map(&:status).sort
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "departure.departed", subject_id: departure.id).count
  end

  test "lifecycle correction versus a stale departed job leaves active without a second departed audit" do
    departure = eligible_active("Stale Job")
    MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @actor, lock_version: departure.lock_version
    ).call
    departure.reload
    CorrectDepartureSchedule.new(
      agency: @agency, actor: @actor, departure:,
      starts_on: Date.new(2099, 5, 1), ends_on: Date.new(2099, 5, 8), time_zone: "UTC",
      reason: "Postponed", lock_version: departure.lock_version
    ).call
    departure.reload
    departed_audits_before = AuditEvent.where(agency_id: @agency.id, action: "departure.departed", subject_id: departure.id).count

    outcomes = race(2) do |index|
      record = Departure.find(departure.id)
      if index.zero?
        CorrectDepartureLifecycle.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          departure: record,
          reason: "Job was stale",
          lock_version: departure.lock_version
        ).call
      else
        MarkDepartureDeparted.new(
          agency: Agency.find(@agency.id),
          departure: record,
          actor_kind: :system,
          actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER
        ).call
      end
    end

    results = outcomes.grep(AgencyCommand::Result)
    assert_equal 2, results.size
    departure.reload
    assert_equal "active", departure.status
    assert_nil departure.departed_at
    assert_equal 1, AuditEvent.where(agency_id: @agency.id, action: "departure.lifecycle_corrected", subject_id: departure.id).count
    assert_equal departed_audits_before, AuditEvent.where(agency_id: @agency.id, action: "departure.departed", subject_id: departure.id).count
  end

  private

  def eligible_active(name)
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @actor,
      attributes: {
        name:,
        starts_on: Date.new(2026, 6, 1),
        ends_on: Date.new(2026, 6, 8),
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @actor.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @actor, departure:, lock_version: departure.lock_version).call.record
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
