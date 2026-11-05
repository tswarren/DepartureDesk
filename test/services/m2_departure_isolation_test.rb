require "test_helper"

class M2DepartureIsolationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @primary = M2DepartureScenario.celebrity
    @companion = M2DepartureScenario.isolation_companion(@primary)
  end

  test "search returns no foreign rows or foreign-derived counts" do
    home = SearchDepartures.call(agency: @primary.directory.agency, actor: @primary.directory.actor)
    away = SearchDepartures.call(agency: @companion.directory.agency, actor: @companion.directory.actor)
    assert_includes home.records.map(&:id), @primary.departure.id
    assert_not_includes home.records.map(&:id), @companion.departure.id
    assert_includes away.records.map(&:id), @companion.departure.id
    assert_not_includes away.records.map(&:id), @primary.departure.id
    assert_not_includes home.records.map(&:name), @companion.departure.name
    assert_equal 1, home.records.size
    assert_not home.truncated

    user_error = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(
        agency: @primary.directory.agency,
        actor: @primary.directory.actor,
        team_member_id: @companion.fixture_default_task_owner.id
      )
    end
    assert_equal :not_found, user_error.code

    team_error = assert_raises(AgencyCommand::Error) do
      AddDepartureTeamMember.new(
        agency: @primary.directory.agency, actor: @primary.directory.actor,
        departure: @primary.departure, agency_user_id: @companion.fixture_default_task_owner.id
      ).call
    end
    assert_equal :not_found, team_error.code
  end

  test "commands fail before mutation and write no audit for rejected cross-agency work" do
    audits_before = AuditEvent.where(agency_id: @primary.directory.agency.id).count
    companion_audits_before = AuditEvent.where(agency_id: @companion.directory.agency.id).count
    assert_raises(ActiveRecord::RecordNotFound) do
      UpdateDeparture.new(
        agency: @primary.directory.agency,
        actor: @primary.directory.actor,
        departure: @companion.departure,
        attributes: { name: "Crossed" },
        lock_version: @companion.departure.lock_version
      ).call
    end
    assert_equal "Celebrity Beyond Isolation", @companion.departure.reload.name
    assert_equal audits_before, AuditEvent.where(agency_id: @primary.directory.agency.id).count
    assert_equal companion_audits_before, AuditEvent.where(agency_id: @companion.directory.agency.id).count
  end

  test "jobs given a foreign or missing id no-op" do
    companion_session = @companion.directory.actor.sessions.create!(
      credential_version: @companion.directory.actor.credential_version,
      office: @companion.directory.agency.offices.sole
    )
    Current.session = companion_session
    assert_no_difference -> { AuditEvent.where(action: "departure.departed").count } do
      MarkDepartureDepartedJob.perform_now(
        agency_id: @primary.directory.agency.id,
        departure_id: @companion.departure.id
      )
      MarkDepartureDepartedJob.perform_now(
        agency_id: @companion.directory.agency.id,
        departure_id: @primary.departure.id
      )
      MarkDepartureDepartedJob.perform_now(
        agency_id: @primary.directory.agency.id,
        departure_id: SecureRandom.uuid
      )
    end
    assert_equal "not_on_sale", @primary.departure.reload.summary_label
    assert_equal "not_on_sale", @companion.departure.reload.summary_label
  ensure
    Current.reset
  end

  test "jobs depart an eligible primary departure without consulting Current" do
    eligible = eligible_on(@primary, "Keep Current Independent")
    companion_session = @companion.directory.actor.sessions.create!(
      credential_version: @companion.directory.actor.credential_version,
      office: @companion.directory.agency.offices.sole
    )
    Current.session = companion_session

    assert_difference -> { AuditEvent.where(agency_id: @primary.directory.agency.id, action: "departure.departed").count }, 1 do
      MarkDepartureDepartedJob.perform_now(
        agency_id: @primary.directory.agency.id,
        departure_id: eligible.id
      )
    end
    assert_equal "departed", eligible.reload.summary_label
    event = AuditEvent.find_by!(agency_id: @primary.directory.agency.id, action: "departure.departed", subject_id: eligible.id)
    assert_equal "system", event.actor_kind
    assert_equal "not_on_sale", @companion.departure.reload.summary_label
  ensure
    Current.reset
  end

  private

  def eligible_on(shell, name)
    departure = CreateDeparture.new(
      agency: shell.directory.agency,
      actor: shell.directory.actor,
      attributes: {
        name:,
        starts_on: Date.new(2026, 6, 1),
        ends_on: Date.new(2026, 6, 8),
        time_zone: "UTC",
        operating_currency: "USD"
      }
    ).call.record
    MarkDepartureReadyToSell.new(
      agency: shell.directory.agency, actor: shell.directory.actor, departure:, lock_version: departure.lock_version
    ).call.record
  end
end
