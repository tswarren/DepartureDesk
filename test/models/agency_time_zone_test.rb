require "test_helper"

# ADR 0016: one agency time zone; offices are optional and carry none.
class AgencyTimeZoneTest < ActiveSupport::TestCase
  test "offices have no time zone column" do
    assert_not_includes Office.column_names, "default_timezone"
  end

  test "Departures have no responsible office or user; the team replaces them (ACC-09)" do
    assert_not_includes Departure.column_names, "responsible_office_id"
    assert_not_includes Departure.column_names, "responsible_agency_user_id"
  end

  test "the database accepts a Ready to sell departure with no office and no team" do
    departure = agencies(:harbor).departures.create!(
      name: "No Office Week",
      departure_reference: "DEP-9999",
      starts_on: Date.new(2027, 3, 1),
      ends_on: Date.new(2027, 3, 8),
      time_zone: "America/New_York",
      operating_currency: "USD"
    )

    assert_nothing_raised do
      Departure.where(id: departure.id).update_all(sales_status: "ready_to_sell")
    end
    assert departure.reload.ready_to_sell?
    assert_empty departure.team_members
  end
end
