require "test_helper"

class AlphaFixtureTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Alpha Fixture #{suffix}",
      workspace_code: "alpha-#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "America/New_York",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Pat",
      administrator_last_name: "Harbor",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:alpha-fixture-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
  end

  test "loads the Alpha suppliers and Departure" do
    alpha = AlphaFixture.load!(agency: @agency, actor: @actor)

    assert_equal [ "Alpha Cruises", "Sablewater Harbor Hotel", "Shore Excursions Group" ],
      @agency.suppliers.order(:display_name).pluck(:display_name)
    assert_equal [ "cruise_line" ], alpha.suppliers.fetch(:cruise).category_assignments.pluck(:category_code)
    assert_equal [ "lodging" ], alpha.suppliers.fetch(:hotel).category_assignments.pluck(:category_code)
    assert_equal [ "activity_attraction" ], alpha.suppliers.fetch(:excursion).category_assignments.pluck(:category_code)

    departure = alpha.departure
    assert_equal "Alpha Omega", departure.name
    assert_equal Date.new(2027, 11, 6), departure.starts_on
    assert_equal Date.new(2027, 11, 13), departure.ends_on
    assert_equal "America/New_York", departure.time_zone
    assert_equal "USD", departure.operating_currency
    assert_equal "DEP-0001", departure.departure_reference
    assert_equal "on_sale", departure.summary_label
    assert departure.decision_proceed?
    assert_equal @actor, departure.default_task_owner
  end

  test "loading twice reuses the records" do
    first = AlphaFixture.load!(agency: @agency, actor: @actor)
    second = AlphaFixture.load!(agency: @agency, actor: @actor)

    assert_equal 3, @agency.suppliers.count
    assert_equal 1, @agency.departures.count
    assert_equal first.departure, second.departure
    assert_equal 1, second.departure.decisions.count
    assert_equal first.suppliers.transform_values(&:id), second.suppliers.transform_values(&:id)
  end
end
