require "test_helper"

class M2DepartureQueryCountTest < ActionDispatch::IntegrationTest
  setup do
    @shell = M2DepartureScenario.celebrity
    sign_in_as @shell.directory.actor
  end

  test "search query counts stay flat from 5 to 50 matching departures" do
    5.times do |index|
      create_counted_departure(format("Fivehit N%02d", index), Date.new(2028, 3, 1) + index)
    end
    50.times do |index|
      create_counted_departure(format("Volpack N%02d", index), Date.new(2028, 4, 1) + index)
    end

    SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Fivehit")
    SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Volpack")

    five = SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Fivehit")
    fifty = SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Volpack")
    assert_equal 5, five.records.size
    assert_equal 50, fifty.records.size

    five_selects = select_query_count do
      SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Fivehit")
    end
    fifty_selects = select_query_count do
      SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Volpack")
    end
    assert_equal five_selects, fifty_selects

    five_rank = search_rank_query_count do
      SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Fivehit")
    end
    fifty_rank = search_rank_query_count do
      SearchDepartures.call(agency: @shell.directory.agency, actor: @shell.directory.actor, query: "Volpack")
    end
    assert_equal five_rank, fifty_rank
  end

  test "index GET query count does not grow from 5 to 50 departures" do
    4.times do |index|
      CreateDeparture.new(
        agency: @shell.directory.agency,
        actor: @shell.directory.actor,
        attributes: { name: "Index Five #{index}" }
      ).call
    end
    get departures_path
    five = request_query_count { get departures_path }

    45.times do |index|
      CreateDeparture.new(
        agency: @shell.directory.agency,
        actor: @shell.directory.actor,
        attributes: { name: "Index Fifty #{index}" }
      ).call
    end
    get departures_path
    fifty = request_query_count { get departures_path }
    assert_equal five, fifty
  end

  test "profile GET query count does not grow with unrelated directory volume" do
    path = departure_path(@shell.departure)
    get path
    baseline = request_query_count { get path }
    20.times do |index|
      CreateClientPersonEmailAddress.new(
        agency: @shell.directory.agency,
        actor: @shell.directory.actor,
        client_person: @shell.directory.martha,
        attributes: { address: "vol-#{index}-#{@shell.directory.suffix}@example.test" }
      ).call
      CreateSupplierEmailAddress.new(
        agency: @shell.directory.agency,
        actor: @shell.directory.actor,
        supplier: @shell.directory.celebrity,
        attributes: { address: "sup-vol-#{index}-#{@shell.directory.suffix}@example.test" }
      ).call
    end
    assert_equal baseline, request_query_count { get path }
  end

  private

  def create_counted_departure(name, starts_on)
    CreateDeparture.new(
      agency: @shell.directory.agency,
      actor: @shell.directory.actor,
      attributes: {
        name:,
        starts_on:,
        ends_on: starts_on + 7,
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: @shell.fixture_responsible_office.id,
        responsible_agency_user_id: @shell.directory.actor.id
      }
    ).call
  end

  def request_query_count
    select_query_count { yield }
  end

  def select_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end

  def search_rank_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].include?("search_rank") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.size
  end
end
