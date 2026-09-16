require "test_helper"

class DepartureCorrectionsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
  end

  test "schedule correction updates the complete final schedule and does not un-depart" do
    departure = departed_record("Schedule Fix")
    CorrectDepartureSchedule.new(
      agency: @agency, actor: @admin, departure:,
      starts_on: Date.new(2027, 1, 10), ends_on: Date.new(2027, 1, 17), time_zone: "UTC",
      reason: "Printed dates were wrong", lock_version: departure.lock_version
    ).call
    departure.reload
    assert_equal "departed", departure.status
    assert_equal Date.new(2027, 1, 10), departure.starts_on
    assert_equal "UTC", departure.time_zone
    event = AuditEvent.find_by!(action: "departure.schedule_corrected", subject_id: departure.id)
    assert_includes event.details["changed_fields"], "starts_on"
    assert_equal "Printed dates were wrong", event.details["reason"]
  end

  test "schedule blanks and correction no-ops require a current lock and valid reason" do
    departure = departed_record("Schedule Noop")
    blank = assert_raises(AgencyCommand::Error) do
      CorrectDepartureSchedule.new(
        agency: @agency, actor: @admin, departure:,
        starts_on: "", ends_on: "", time_zone: "",
        reason: "fix", lock_version: departure.lock_version
      ).call
    end
    assert_equal :invalid, blank.code

    stale = assert_raises(AgencyCommand::Error) do
      CorrectDepartureSchedule.new(
        agency: @agency, actor: @admin, departure:,
        starts_on: departure.starts_on, ends_on: departure.ends_on, time_zone: departure.time_zone,
        reason: "same", lock_version: departure.lock_version - 1
      ).call
    end
    assert_equal :conflict, stale.code

    blank_reason = assert_raises(AgencyCommand::Error) do
      CorrectDepartureSchedule.new(
        agency: @agency, actor: @admin, departure:,
        starts_on: departure.starts_on, ends_on: departure.ends_on, time_zone: departure.time_zone,
        reason: " ", lock_version: departure.lock_version
      ).call
    end
    assert_equal :invalid, blank_reason.code

    result = CorrectDepartureSchedule.new(
      agency: @agency, actor: @admin, departure:,
      starts_on: departure.starts_on, ends_on: departure.ends_on, time_zone: departure.time_zone,
      reason: "no change", lock_version: departure.lock_version
    ).call
    assert_equal :noop, result.status
    assert_equal 0, AuditEvent.where(action: "departure.schedule_corrected", subject_id: departure.id).count
  end

  test "currency correction succeeds and active currency stays on UpdateDeparture" do
    departure = departed_record("Currency Fix")
    CorrectDepartureCurrency.new(
      agency: @agency, actor: @admin, departure:, operating_currency: "EUR",
      reason: "Quoted in euro", lock_version: departure.lock_version
    ).call
    assert_equal "EUR", departure.reload.operating_currency
    event = AuditEvent.find_by!(action: "departure.currency_corrected", subject_id: departure.id)
    assert_equal "USD", event.details["prior_operating_currency"]
    assert_equal "EUR", event.details["operating_currency"]
  end

  test "lifecycle correction returns to active only when starts_on is still in the future" do
    departure = departed_record("Lifecycle")
    CorrectDepartureSchedule.new(
      agency: @agency, actor: @admin, departure:,
      starts_on: Date.new(2099, 3, 1), ends_on: Date.new(2099, 3, 8), time_zone: departure.time_zone,
      reason: "Sailing was postponed", lock_version: departure.lock_version
    ).call
    CorrectDepartureLifecycle.new(
      agency: @agency, actor: @admin, departure:, reason: "Marked departed too soon", lock_version: departure.reload.lock_version
    ).call
    departure.reload
    assert_equal "active", departure.status
    assert_nil departure.departed_at
    assert_equal "D-000001", departure.departure_reference
    event = AuditEvent.find_by!(action: "departure.lifecycle_corrected", subject_id: departure.id)
    assert_equal "departed", event.details["prior_status"]
    assert_nil event.details["departed_at"]

    past = departed_record("Already Started", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))
    too_late = assert_raises(AgencyCommand::Error) do
      CorrectDepartureLifecycle.new(
        agency: @agency, actor: @admin, departure: past, reason: "undo", lock_version: past.lock_version
      ).call
    end
    assert_equal :invalid_state, too_late.code
  end

  test "schedule correction does not return a departure to active" do
    departure = departed_record("Still Departed", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))
    CorrectDepartureSchedule.new(
      agency: @agency, actor: @admin, departure:,
      starts_on: Date.new(2099, 4, 1), ends_on: Date.new(2099, 4, 8), time_zone: departure.time_zone,
      reason: "Moved to next year", lock_version: departure.lock_version
    ).call
    assert_equal "departed", departure.reload.status
    assert_not_nil departure.departed_at
    assert_equal 0, AuditEvent.where(action: "departure.lifecycle_corrected", subject_id: departure.id).count
  end

  test "viewer cannot correct a departed departure" do
    departure = departed_record("Viewer Correction")
    error = assert_raises(AgencyCommand::Error) do
      CorrectDepartureCurrency.new(
        agency: @agency, actor: @viewer, departure:, operating_currency: "EUR",
        reason: "nope", lock_version: departure.lock_version
      ).call
    end
    assert_equal :unauthorized, error.code
  end

  test "corrections against draft or active are invalid_state" do
    draft = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Not Departed" }).call.record
    error = assert_raises(AgencyCommand::Error) do
      CorrectDepartureCurrency.new(
        agency: @agency, actor: @admin, departure: draft, operating_currency: "EUR",
        reason: "nope", lock_version: draft.lock_version
      ).call
    end
    assert_equal :invalid_state, error.code
  end

  private

  def departed_record(name, starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8))
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
    departure = ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
    MarkDepartureDeparted.new(
      agency: @agency, departure:, actor_kind: :agency_user, actor: @admin, lock_version: departure.lock_version
    ).call.record
  end
end
