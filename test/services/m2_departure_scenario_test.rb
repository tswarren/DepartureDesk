require "test_helper"

class M2DepartureScenarioTest < ActiveSupport::TestCase
  test "celebrity and vineyard shells are independent drafts with fixture-only operating facts" do
    celebrity = M2DepartureScenario.celebrity
    vineyard = M2DepartureScenario.vineyard

    assert_equal "Celebrity Beyond", celebrity.departure.name
    assert_equal Date.new(2027, 11, 6), celebrity.departure.starts_on
    assert_equal Date.new(2027, 11, 13), celebrity.departure.ends_on
    assert celebrity.departure.draft?
    assert_nil celebrity.departure.departure_reference
    assert_equal celebrity.directory.agency.default_currency, celebrity.fixture_operating_currency
    assert_equal celebrity.directory.agency.default_timezone, celebrity.fixture_time_zone
    assert_equal celebrity.directory.agency.offices.sole.id, celebrity.fixture_responsible_office.id
    assert_equal celebrity.directory.actor.id, celebrity.fixture_responsible_agency_user.id

    assert_equal "Vineyard Tour", vineyard.departure.name
    assert_equal Date.new(2027, 6, 5), vineyard.departure.starts_on
    assert_equal Date.new(2027, 6, 7), vineyard.departure.ends_on
    assert vineyard.departure.draft?
    assert_nil vineyard.departure.departure_reference
    assert_not_equal celebrity.directory.agency.id, vineyard.directory.agency.id

    assert_equal 1, celebrity.directory.agency.departures.count
    assert_equal 1, vineyard.directory.agency.departures.count
    assert_not File.exist?(Rails.root.join("app/models/travel_program.rb"))
    assert_nil Rails.application.routes.named_routes.get("travel_programs")
    assert_not ActiveRecord::Base.connection.data_source_exists?("travel_programs")
    assert_not ActiveRecord::Base.connection.data_source_exists?("packages")
    assert_not ActiveRecord::Base.connection.data_source_exists?("client_trips")
  end

  test "activation return and reactivation keep a single D- reference" do
    shell = M2DepartureScenario.celebrity
    departure = shell.departure
    actor = shell.directory.actor
    agency = shell.directory.agency

    activated = ActivateDeparture.new(agency:, actor:, departure:, lock_version: departure.lock_version).call.record
    assert_equal "D-000001", activated.departure_reference
    returned = ReturnDepartureToDraft.new(
      agency:, actor:, departure: activated, reason: "Hold the sailing", lock_version: activated.lock_version
    ).call.record
    assert_equal "draft", returned.status
    assert_equal "D-000001", returned.departure_reference
    reactivated = ActivateDeparture.new(agency:, actor:, departure: returned, lock_version: returned.lock_version).call.record
    assert_equal "D-000001", reactivated.departure_reference
    assert_equal 1, agency.departures.where.not(departure_reference: nil).count
  end

  test "viewer browses and cannot mutate" do
    shell = M2DepartureScenario.celebrity
    error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(
        agency: shell.directory.agency,
        actor: shell.directory.viewer,
        departure: shell.departure,
        attributes: { name: "Nope" },
        lock_version: shell.departure.lock_version
      ).call
    end
    assert_equal :unauthorized, error.code
    assert_equal "Celebrity Beyond", shell.departure.reload.name
    assert_includes SearchDepartures.call(agency: shell.directory.agency, actor: shell.directory.viewer).records.map(&:id),
      shell.departure.id
  end

  test "cleanup extracts agencies and deletes their departures" do
    shell = M2DepartureScenario.celebrity
    agency_id = shell.directory.agency.id
    departure_id = shell.departure.id
    M2DepartureScenario.cleanup!(shell)
    assert_nil Departure.find_by(id: departure_id)
    assert_nil Agency.find_by(id: agency_id)
  end

  test "parent-acceptance authorities remain consistent without loading TravelProgram" do
    adr7 = File.read(Rails.root.join("docs/adr/0007-departure-operational-root.md"))
    assert_match(/^- Status: Accepted/i, adr7)
    adr4 = File.read(Rails.root.join("docs/adr/0004-human-readable-references.md"))
    assert_match(/Namespace \| `departure`/, adr4)
    assert_match(/D-%06d/, adr4)
    assert_equal "departure", ReferenceSequence::DEPARTURE_NAMESPACE
    assert_nil defined?(TravelProgram)
    assert_not File.exist?(Rails.root.join("app/models/travel_program.rb"))
    assert_not File.exist?(Rails.root.join("test/fixtures/travel_programs.yml"))
    assert_nil Rails.application.routes.named_routes.get("travel_programs")
    assert_not ActiveRecord::Base.connection.data_source_exists?("travel_programs")
  end
end
