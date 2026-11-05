require "test_helper"

# ADR 0016: one agency time zone; offices are optional and carry none.
class AgencyTimeZoneTest < ActiveSupport::TestCase
  test "offices have no time zone column" do
    assert_not_includes Office.column_names, "default_timezone"
  end

  test "the database accepts an active departure without a responsible office" do
    departure = agencies(:harbor).departures.create!(
      name: "No Office Week",
      departure_reference: "DEP-9999",
      starts_on: Date.new(2027, 3, 1),
      ends_on: Date.new(2027, 3, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_agency_user: agency_users(:harbor_admin)
    )

    assert_nothing_raised do
      Departure.where(id: departure.id).update_all(
        sales_status: "ready_to_sell"
      )
    end
    assert_nil departure.reload.responsible_office_id
  end

  test "the database still requires a responsible agency user to leave draft" do
    departure = agencies(:harbor).departures.create!(
      name: "No User Week",
      departure_reference: "DEP-9998",
      starts_on: Date.new(2027, 3, 1),
      ends_on: Date.new(2027, 3, 8),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Departure.transaction(requires_new: true) do
        Departure.where(id: departure.id).update_all(
          sales_status: "ready_to_sell"
        )
      end
    end
  end
end
