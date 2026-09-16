require "test_helper"

class DepartureEligibilityTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @office = offices(:harbor_main)
  end

  test "SQL selector and Ruby predicate agree across zones for the same instant" do
    instant = Time.utc(2026, 6, 15, 4, 0, 0)

    {
      "UTC" => { eligible: Date.new(2026, 6, 15), ineligible: Date.new(2026, 6, 16) },
      "America/Los_Angeles" => { eligible: Date.new(2026, 6, 14), ineligible: Date.new(2026, 6, 15) },
      "Asia/Tokyo" => { eligible: Date.new(2026, 6, 15), ineligible: Date.new(2026, 6, 16) },
      "America/New_York" => { eligible: Date.new(2026, 6, 15), ineligible: Date.new(2026, 6, 16) }
    }.each do |zone, dates|
      eligible = active_departure("Eligible #{zone}", time_zone: zone, starts_on: dates[:eligible], ends_on: dates[:eligible] + 7)
      ineligible = active_departure("Ineligible #{zone}", time_zone: zone, starts_on: dates[:ineligible], ends_on: dates[:ineligible] + 7)

      assert_equal true, eligible.eligible_to_depart?(at: instant), zone
      assert_equal true, Departure.eligible_to_depart_relation(at: instant).exists?(id: eligible.id), "#{zone} SQL eligible"
      assert_equal false, ineligible.eligible_to_depart?(at: instant), zone
      assert_equal false, Departure.eligible_to_depart_relation(at: instant).exists?(id: ineligible.id), "#{zone} SQL ineligible"
    end

    east_instant = Time.utc(2026, 6, 15, 16, 0, 0)
    tokyo = active_departure("Tokyo crossing", time_zone: "Asia/Tokyo", starts_on: Date.new(2026, 6, 16), ends_on: Date.new(2026, 6, 23))
    utc = active_departure("UTC crossing", time_zone: "UTC", starts_on: Date.new(2026, 6, 16), ends_on: Date.new(2026, 6, 23))
    assert_equal true, tokyo.eligible_to_depart?(at: east_instant)
    assert_equal true, Departure.eligible_to_depart_relation(at: east_instant).exists?(id: tokyo.id)
    assert_equal false, utc.eligible_to_depart?(at: east_instant)
    assert_equal false, Departure.eligible_to_depart_relation(at: east_instant).exists?(id: utc.id)
  end

  test "lifecycle correction is allowed only when stored starts_on is later than local date" do
    instant = Time.utc(2026, 6, 15, 16, 0, 0)
    future = departed_departure("Future Start", starts_on: Date.new(2026, 6, 16), ends_on: Date.new(2026, 6, 20), time_zone: "UTC")
    today = departed_departure("Today Start", starts_on: Date.new(2026, 6, 15), ends_on: Date.new(2026, 6, 20), time_zone: "UTC")

    assert future.lifecycle_correction_allowed?(at: instant)
    assert_not today.lifecycle_correction_allowed?(at: instant)
  end

  private

  def active_departure(name, time_zone:, starts_on:, ends_on:)
    departure = CreateDeparture.new(
      agency: @agency,
      actor: @admin,
      attributes: {
        name:,
        starts_on:,
        ends_on:,
        time_zone:,
        operating_currency: "USD",
        responsible_office_id: @office.id,
        responsible_agency_user_id: @admin.id
      }
    ).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure:, lock_version: departure.lock_version).call.record
  end

  def departed_departure(name, **schedule)
    departure = active_departure(name, **schedule)
    Departure.where(id: departure.id).update_all(status: "departed", departed_at: Time.utc(2026, 6, 1), updated_at: Time.current)
    departure.reload
  end
end
