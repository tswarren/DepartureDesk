require "test_helper"

class M2DepartureSearchPerformanceTest < ActiveSupport::TestCase
  setup do
    @shell = M2DepartureScenario.celebrity
    @agency = @shell.directory.agency
    @actor = @shell.directory.actor
    @office = @shell.fixture_responsible_office
    @west = CreateOffice.new(agency: @agency, actor: @actor, name: "West Desk", code: "WEST", default_timezone: "UTC").call.record
    @staff = @agency.agency_users.create!(
      email_address: "staff-#{@shell.directory.suffix}@example.test",
      first_name: "Sid",
      last_name: "Staff",
      password: M1DirectoryScenario::PASSWORD,
      access_role: "staff",
      status: "active",
      default_office: @office,
      credential_version: 1
    )

    @alpha = extra_departure("Alpha Voyage", starts_on: Date.new(2026, 5, 1), ends_on: Date.new(2026, 5, 8))
    extra_departure("Beta Voyage", starts_on: Date.new(2026, 6, 1), ends_on: Date.new(2026, 6, 8), office: @west)
    @gamma = extra_departure("Gamma Voyage", starts_on: Date.new(2026, 7, 1), ends_on: Date.new(2026, 7, 8), user: @staff)
    ActivateDeparture.new(agency: @agency, actor: @actor, departure: @gamma, lock_version: @gamma.lock_version).call
    @gamma.reload
    @delta = extra_departure("Delta Voyage", starts_on: Date.new(2026, 4, 1), ends_on: Date.new(2026, 4, 8))
    ActivateDeparture.new(agency: @agency, actor: @actor, departure: @delta, lock_version: @delta.lock_version).call
    MarkDepartureDeparted.new(
      agency: @agency, departure: @delta.reload, actor_kind: :agency_user, actor: @actor, lock_version: @delta.lock_version
    ).call
    @delta.reload
    refresh_statistics!
  end

  test "search branches return the right records before EXPLAIN" do
    assert_equal [ "Alpha Voyage" ], names_for(query: "Alpha Voyage")
    assert_equal 2, rank_for(query: "Alpha Voyage")

    assert_equal [ "Gamma Voyage" ], names_for(query: @gamma.departure_reference)
    assert_equal 1, rank_for(query: @gamma.departure_reference)

    assert_includes names_for(query: "beta"), "Beta Voyage"
    assert_not_includes names_for(query: "betaz"), "Beta Voyage"

    drafts = names_for(status: "draft")
    assert_includes drafts, "Celebrity Beyond"
    assert_includes drafts, "Alpha Voyage"
    assert_not_includes drafts, "Gamma Voyage"
    assert_not_includes drafts, "Delta Voyage"

    assert_equal [ "Gamma Voyage" ], names_for(status: "active")
    assert_equal [ "Delta Voyage" ], names_for(status: "departed")
    all_names = names_for(status: "all")
    assert_includes all_names, "Celebrity Beyond"
    assert_includes all_names, "Gamma Voyage"
    assert_includes all_names, "Delta Voyage"

    assert_equal [ "Beta Voyage" ], names_for(responsible_office_id: @west.id)
    assert_equal [ "Gamma Voyage" ], names_for(responsible_agency_user_id: @staff.id)

    assert_equal [ "Alpha Voyage" ], names_for(starts_on_from: "2026-05-01", starts_on_to: "2026-05-01")
    assert_not_includes names_for(starts_on_from: "2026-05-02"), "Alpha Voyage"
    assert_not_includes names_for(starts_on_to: "2026-04-30"), "Alpha Voyage"
    assert_equal [ "Beta Voyage" ], names_for(ends_on_from: "2026-06-08", ends_on_to: "2026-06-08")
    assert_not_includes names_for(ends_on_from: "2026-06-09"), "Beta Voyage"
    assert_not_includes names_for(ends_on_to: "2026-06-07"), "Beta Voyage"

    blank = names_for
    assert_includes blank, "Celebrity Beyond"
    assert_includes blank, "Alpha Voyage"
    assert_includes blank, "Delta Voyage"

    combined = SearchDepartures.call(
      agency: @agency, actor: @actor, query: "Gamma", status: "active",
      responsible_office_id: @office.id, starts_on_from: "2026-07-01", starts_on_to: "2026-07-01"
    ).records
    assert_equal [ "Gamma Voyage" ], combined.map(&:name)
    combined.each do |row|
      assert_equal "active", row.status
      assert_equal @office.id, row.responsible_office_id
      assert_equal Date.new(2026, 7, 1), row.starts_on
      assert_match(/gamma/i, row.name)
    end
  end

  test "cap semantics fetch 51 return 50 and identify the lookahead" do
    51.times do |index|
      extra_departure(format("Capcount N%02d", index), starts_on: Date.new(2028, 1, 1) + index, ends_on: Date.new(2028, 1, 8) + index)
    end
    relation = SearchDepartures.composed_relation(agency: @agency, actor: @actor, query: "Capcount")
    assert_equal SearchDepartures::FETCH_LIMIT, relation.limit_value
    assert_match(/LIMIT (?:51|\$\d+)/, relation.to_sql)
    rows = relation.to_a
    assert_equal 51, rows.size
    outcome = SearchDepartures.call(agency: @agency, actor: @actor, query: "Capcount")
    assert_equal 50, outcome.records.size
    assert outcome.truncated
    assert_equal rows.first(50).map(&:id), outcome.records.map(&:id)
    assert_not_includes outcome.records.map(&:id), rows.last.id

    fifty_rows = 50.times.map do |index|
      extra_departure(format("Exactfifty N%02d", index), starts_on: Date.new(2029, 1, 1) + index, ends_on: Date.new(2029, 1, 8) + index)
    end
    fifty = SearchDepartures.call(agency: @agency, actor: @actor, query: "Exactfifty")
    assert_equal 50, fifty.records.size
    assert_not fifty.truncated
    expected = fifty_rows.map(&:reload).sort_by { |row| [ row.starts_on, row.name_search_key, row.id ] }.map(&:id)
    assert_equal expected, fifty.records.map(&:id)
  end

  test "EXPLAIN uses the expected supporting index for each composed branch" do
    companion = M2DepartureScenario.isolation_companion(@shell)
    seed_agency_volume!(@agency, "Plannervol", 800, office: @office, user: @actor)
    seed_agency_volume!(
      companion.directory.agency, "Foreignvol", 800,
      office: companion.fixture_responsible_office, user: companion.directory.actor
    )
    51.times do |index|
      extra_departure(
        format("Lookaheadvol N%02d", index),
        starts_on: Date.new(2028, 3, 1) + index,
        ends_on: Date.new(2028, 3, 8) + index
      )
    end
    refresh_statistics!

    lookahead = SearchDepartures.composed_relation(agency: @agency, actor: @actor, query: "Lookaheadvol")
    assert_equal SearchDepartures::FETCH_LIMIT, lookahead.limit_value
    assert_equal 51, lookahead.to_a.size

    # Status-filtered and sweep selectors still order by starts_on, so PostgreSQL
    # may use either named composite. Generic tenant indexes (agency_id /
    # id+agency_id) are not accepted.
    status_indexes = /index_departures_on_agency_status_starts_on_id|index_departures_on_agency_starts_on_name_id/
    [
      [ "blank browse", {}, "index_departures_on_agency_starts_on_name_id" ],
      [ "status all", { status: "all" }, "index_departures_on_agency_starts_on_name_id" ],
      [ "exact name", { query: "Alpha Voyage" }, "index_departures_on_agency_and_name_search_key" ],
      [ "prefix name", { query: "beta" }, "index_departures_on_agency_and_name_search_key" ],
      [ "exact reference", { query: @gamma.departure_reference }, "index_departures_on_agency_and_reference" ],
      [ "status draft", { status: "draft", starts_on_from: "2026-05-01" }, status_indexes ],
      [ "status active", { status: "active", starts_on_from: "2026-07-01" }, status_indexes ],
      [ "status departed", { status: "departed", starts_on_from: "2026-04-01" }, status_indexes ],
      [ "office filter", { responsible_office_id: @west.id }, "index_departures_on_agency_office_starts_on_id" ],
      [ "user filter", { responsible_agency_user_id: @staff.id }, "index_departures_on_agency_user_starts_on_id" ],
      [ "starts_on range", { starts_on_from: "2026-05-01", starts_on_to: "2026-05-08" }, "index_departures_on_agency_starts_on_name_id" ],
      [ "ends_on range", { ends_on_from: "2026-06-01", ends_on_to: "2026-06-08" }, "index_departures_on_agency_ends_on_id" ],
      [ "51-row lookahead", { query: "Lookaheadvol" }, "index_departures_on_agency_and_name_search_key" ]
    ].each do |label, kwargs, index_name|
      relation = SearchDepartures.composed_relation(agency: @agency, actor: @actor, **kwargs)
      assert_equal SearchDepartures::FETCH_LIMIT, relation.limit_value if label == "51-row lookahead"
      assert_index_eligible(relation, index_name, label)
    end

    sweep = MarkEligibleDeparturesDepartedJob.candidate_relation(at: Time.utc(2026, 6, 15, 12, 0, 0))
    assert_index_eligible(sweep, status_indexes, "sweep selector")
  end

  private

  def names_for(**kwargs)
    SearchDepartures.call(agency: @agency, actor: @actor, **kwargs).records.map(&:name)
  end

  def rank_for(**kwargs)
    SearchDepartures.composed_relation(agency: @agency, actor: @actor, **kwargs).first.read_attribute("search_rank")
  end

  def extra_departure(name, starts_on:, ends_on:, office: @office, user: @actor)
    CreateDeparture.new(
      agency: @agency,
      actor: @actor,
      attributes: {
        name:,
        starts_on:,
        ends_on:,
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: office.id,
        responsible_agency_user_id: user.id
      }
    ).call.record
  end

  def seed_agency_volume!(agency, prefix, count, office:, user:)
    now = Time.current
    rows = Array.new(count) do |index|
      starts_on = Date.new(2023, 1, 1) + index
      {
        agency_id: agency.id,
        name: format("%s %04d", prefix, index),
        starts_on:,
        ends_on: starts_on + 7,
        time_zone: "UTC",
        operating_currency: "USD",
        responsible_office_id: office.id,
        responsible_agency_user_id: user.id,
        status: "active",
        departure_reference: format("D-%06d", index + 10),
        first_activated_at: now,
        lock_version: 0,
        created_at: now,
        updated_at: now
      }
    end
    Departure.insert_all(rows)
  end

  def refresh_statistics!
    ActiveRecord::Base.connection.execute("ANALYZE departures")
    ActiveRecord::Base.connection.execute("ANALYZE agencies")
  end

  def assert_index_eligible(relation, index_name, label)
    plan = explain(relation)
    assert_match(/Index Scan|Bitmap Index Scan|Bitmap Heap Scan|Index Only Scan/, plan, "#{label}: #{plan}")
    pattern = index_name.is_a?(Regexp) ? index_name : /#{Regexp.escape(index_name)}/
    assert_match(pattern, plan, "#{label}: #{plan}")
  end

  def explain(relation)
    plan = nil
    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL enable_seqscan = off")
      plan = relation.explain.inspect
      raise ActiveRecord::Rollback
    end
    plan
  end
end
