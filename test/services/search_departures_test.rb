require "test_helper"

class SearchDeparturesTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @other = agencies(:cove)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @office = offices(:harbor_main)
    @west = offices(:harbor_west)
    CreateDeparture.new(agency: @agency, actor: @admin, attributes: complete_attrs(name: "Alpha Voyage", starts_on: Date.new(2026, 5, 1), ends_on: Date.new(2026, 5, 8))).call
    CreateDeparture.new(agency: @agency, actor: @admin, attributes: complete_attrs(name: "Beta Voyage", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8), responsible_office_id: @west.id)).call
    gamma = CreateDeparture.new(agency: @agency, actor: @admin, attributes: complete_attrs(name: "Gamma Voyage", starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 8))).call.record
    ActivateDeparture.new(agency: @agency, actor: @admin, departure: gamma, lock_version: gamma.lock_version).call
    CreateDeparture.new(agency: @other, actor: agency_users(:cove_admin), attributes: { name: "Cove Secret", starts_on: Date.new(2026, 5, 1), ends_on: Date.new(2026, 5, 8) }).call
  end

  test "blank query browses in deterministic date order and includes other-agency isolation" do
    outcome = SearchDepartures.call(agency: @agency, actor: @viewer)
    names = outcome.records.map(&:name)
    assert_equal [ "Alpha Voyage", "Beta Voyage", "Gamma Voyage" ], names
    assert_not outcome.truncated
  end

  test "default order remains date then normalized name then id after rank" do
    assert_equal "search_rank ASC, starts_on ASC NULLS LAST, name_search_key ASC, id ASC", SearchDepartures::DEFAULT_ORDER.to_s
  end

  test "search ranks exact reference, then exact name, then prefix" do
    gamma = @agency.departures.find_by!(name: "Gamma Voyage")
    ranked = SearchDepartures.call(agency: @agency, actor: @admin, query: gamma.departure_reference).records
    assert_equal [ "Gamma Voyage" ], ranked.map(&:name)
    assert_equal 1, ranked.first.read_attribute("search_rank")

    exact = SearchDepartures.call(agency: @agency, actor: @admin, query: "Alpha Voyage").records
    assert_equal "Alpha Voyage", exact.first.name
    assert_equal 2, exact.first.read_attribute("search_rank")

    prefix = SearchDepartures.call(agency: @agency, actor: @admin, query: "beta").records
    assert_equal "Beta Voyage", prefix.first.name
    assert_equal 3, prefix.first.read_attribute("search_rank")
  end

  test "filters fail closed for unknown status, malformed values, reversed range, and foreign ids" do
    invalid_status = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: @admin, status: "archived")
    end
    assert_equal :invalid, invalid_status.code

    malformed_date = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: @admin, starts_on_from: "not-a-date")
    end
    assert_equal :invalid, malformed_date.code

    malformed_uuid = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: @admin, responsible_office_id: "bad")
    end
    assert_equal :invalid, malformed_uuid.code

    reversed = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: @admin, starts_on_from: "2026-07-01", starts_on_to: "2026-06-01")
    end
    assert_equal :invalid, reversed.code

    foreign = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: @admin, responsible_office_id: offices(:cove_main).id)
    end
    assert_equal :not_found, foreign.code
  end

  test "query longer than 100 characters is invalid and unauthorized actors cannot search" do
    too_long = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: @admin, query: "a" * 101)
    end
    assert_equal :invalid, too_long.code

    unauthorized = assert_raises(AgencyCommand::Error) do
      SearchDepartures.call(agency: @agency, actor: agency_users(:cove_admin))
    end
    assert_equal :unauthorized, unauthorized.code
  end

  test "search cap reports truncation after fetching 51" do
    48.times do |index|
      CreateDeparture.new(
        agency: @agency,
        actor: @admin,
        attributes: complete_attrs(name: "Extra #{index.to_s.rjust(2, "0")}", starts_on: Date.new(2027, 1, 1) + index, ends_on: Date.new(2027, 1, 8) + index)
      ).call
    end

    relation = SearchDepartures.composed_relation(agency: @agency, actor: @admin)
    assert_equal 51, relation.to_a.size
    outcome = SearchDepartures.call(agency: @agency, actor: @admin)
    assert_equal 50, outcome.records.size
    assert outcome.truncated
  end

  private

  def complete_attrs(overrides = {})
    {
      name: "Named Departure",
      starts_on: Date.new(2026, 6, 1),
      ends_on: Date.new(2026, 6, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_office_id: @office.id,
      responsible_agency_user_id: @admin.id
    }.merge(overrides)
  end
end
