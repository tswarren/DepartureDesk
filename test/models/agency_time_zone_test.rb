require "test_helper"

# ADR 0016: one agency time zone; offices are optional and carry none.
class AgencyTimeZoneTest < ActiveSupport::TestCase
  test "offices have no time zone column" do
    assert_not_includes Office.column_names, "default_timezone"
  end

  test "the database accepts an active departure without a responsible office" do
    departure = agencies(:harbor).departures.create!(
      name: "No Office Week",
      starts_on: Date.new(2027, 3, 1),
      ends_on: Date.new(2027, 3, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_agency_user: agency_users(:harbor_admin)
    )

    assert_nothing_raised do
      Departure.where(id: departure.id).update_all(
        status: "active", departure_reference: "DEP-9999", first_activated_at: Time.current
      )
    end
    assert_nil departure.reload.responsible_office_id
  end

  test "the database still requires a responsible agency user to leave draft" do
    departure = agencies(:harbor).departures.create!(
      name: "No User Week",
      starts_on: Date.new(2027, 3, 1),
      ends_on: Date.new(2027, 3, 8),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(
          status: "active", departure_reference: "DEP-9998", first_activated_at: Time.current
        )
      end
    end
  end
end
