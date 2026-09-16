require "test_helper"

class MarkDepartureDepartedTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
  end

  test "user invocation marks an eligible departure departed with one audit" do
    departure = eligible_active("Manual Depart")
    freeze_time do
      result = MarkDepartureDeparted.new(
        agency: @agency, departure:, actor_kind: :agency_user, actor: @staff, lock_version: departure.lock_version
      ).call
      departure.reload
      assert_equal :updated, result.status
      assert_equal "departed", departure.status
      assert_equal Time.current, departure.departed_at
      event = AuditEvent.find_by!(agency: @agency, action: "departure.departed", subject_id: departure.id)
      assert_equal "agency_user", event.actor_kind
      assert_equal @staff.id, event.actor_agency_user_id
      assert_equal "active", event.details["prior_status"]
      assert_equal "departed", event.details["status"]
    end
  end

  test "system invocation uses the exact identifier and ignores lock_version" do
    departure = eligible_active("Job Depart")
    result = MarkDepartureDeparted.new(
      agency: @agency,
      departure:,
      actor_kind: :system,
      actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER,
      lock_version: 0
    ).call
    assert_equal :updated, result.status
    event = AuditEvent.find_by!(agency: @agency, action: "departure.departed", subject_id: departure.id)
    assert_equal "system", event.actor_kind
    assert_equal "departures.mark_departed", event.actor_identifier
  end

  test "already departed replay succeeds with a stale lock_version and does not audit" do
    departure = eligible_active("Replay Depart")
    MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @admin, lock_version: departure.lock_version
    ).call
    stale = departure.reload.lock_version - 1
    result = MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @admin, lock_version: stale
    ).call
    assert_equal :noop, result.status
    assert_equal 1, AuditEvent.where(agency: @agency, action: "departure.departed", subject_id: departure.id).count
  end

  test "user ineligible or draft is invalid_state and system races are no-ops" do
    future = eligible_active("Future", starts_on: Date.new(2099, 1, 1), ends_on: Date.new(2099, 1, 8))
    user_future = assert_raises(AgencyCommand::Error) do
      MarkDepartureDeparted.new(
        agency: @agency, departure: future, actor_kind: :agency_user, actor: @admin, lock_version: future.lock_version
      ).call
    end
    assert_equal :invalid_state, user_future.code

    system_future = MarkDepartureDeparted.new(
      agency: @agency, departure: future, actor_kind: :system, actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER
    ).call
    assert_equal :noop, system_future.status
    assert_equal "active", future.reload.status

    draft = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Draft Race" }).call.record
    user_draft = assert_raises(AgencyCommand::Error) do
      MarkDepartureDeparted.new(
        agency: @agency, departure: draft, actor_kind: :agency_user, actor: @admin, lock_version: draft.lock_version
      ).call
    end
    assert_equal :invalid_state, user_draft.code
    system_draft = MarkDepartureDeparted.new(
      agency: @agency, departure: draft, actor_kind: :system, actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER
    ).call
    assert_equal :noop, system_draft.status
    assert_equal 0, AuditEvent.where(action: "departure.departed", subject_id: draft.id).count
  end

  test "invocation matrix rejects every invalid combination" do
    departure = eligible_active("Matrix")
    invalid_calls = [
      { actor_kind: :agency_user, actor: nil, lock_version: departure.lock_version },
      { actor_kind: :agency_user, actor: @admin, actor_identifier: "departures.mark_departed", lock_version: departure.lock_version },
      { actor_kind: :system, actor: @admin, actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER },
      { actor_kind: :system, actor_identifier: "other.identifier" },
      { actor_kind: :system },
      { actor_kind: :job, actor_identifier: MarkDepartureDeparted::SYSTEM_ACTOR_IDENTIFIER }
    ]
    invalid_calls.each do |args|
      error = assert_raises(AgencyCommand::Error, args.inspect) do
        MarkDepartureDeparted.new(agency: @agency, departure:, **args).call
      end
      assert_equal :invalid, error.code, args.inspect
    end
  end

  test "viewer cannot mark departed" do
    departure = eligible_active("Viewer Depart")
    error = assert_raises(AgencyCommand::Error) do
      MarkDepartureDeparted.new(
        agency: @agency, departure:, actor_kind: :agency_user, actor: @viewer, lock_version: departure.lock_version
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "controllers never invoke the system departed path" do
    controller_sources = Rails.root.glob("app/controllers/**/*.rb").map { |path| File.read(path) }.join
    assert_no_match(/actor_kind:\s*:system/, controller_sources)
  end

  private

  def eligible_active(name, starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name:,
        starts_on:,
        ends_on:,
        time_zone: "America/New_York",
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end
end
