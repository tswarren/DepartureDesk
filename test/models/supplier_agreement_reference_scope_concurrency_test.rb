# frozen_string_literal: true

require "test_helper"

class SupplierAgreementReferenceScopeConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Scope Race #{suffix}",
      workspace_code: "s#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_password: TEST_PASSWORD,
      administrator_first_name: "Race",
      administrator_last_name: "Admin",
      actor_identifier: "test:scope-race-#{suffix}"
    ).call.record
    @admin = @agency.agency_users.sole
    @office = @agency.offices.sole
    @departure = @agency.departures.create!(
      name: "Scope race #{suffix}",
      starts_on: Date.new(2027, 11, 4),
      ends_on: Date.new(2027, 11, 6),
      time_zone: "UTC",
      operating_currency: "USD",
      responsible_office: @office,
      responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-#{SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")}",
      display_name: "Scope Race Hotel #{suffix}"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: "Scope race arrangement #{suffix}"
    )
    @version = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1,
      status: "draft"
    )
    @item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @threads = []
    @leased_connections = []
  end

  teardown do
    @threads.each { |thread| thread.kill if thread&.alive? }
    @threads.each { |thread| thread.join(1) if thread }
    @leased_connections.each do |connection|
      connection.rollback_db_transaction if connection.transaction_open?
      ActiveRecord::Base.connection_pool.checkin(connection)
    rescue StandardError
      nil
    end
    @leased_connections.clear

    next unless @agency&.persisted?

    connection = ActiveRecord::Base.connection
    connection.execute("SET session_replication_role = replica")
    agency_id = @agency.id
    SupplierAgreementReference.where(agency_id: agency_id).delete_all
    ArrangementItem.where(agency_id: agency_id).delete_all
    SupplierArrangementVersion.where(agency_id: agency_id).delete_all
    SupplierArrangement.where(agency_id: agency_id).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent opposite scopes let exactly one agreement reference commit" do
    wide_inserted = Queue.new
    release_wide = Queue.new
    item_finished = Queue.new
    wide_connection = ActiveRecord::Base.connection_pool.checkout
    item_connection = ActiveRecord::Base.connection_pool.checkout
    @leased_connections = [ wide_connection, item_connection ]

    wide = Thread.new do
      wide_connection.begin_db_transaction
      wide_connection.execute(insert_sql(wide_connection, item_id: nil, wording: "Agreement-wide fee."))
      wide_inserted << true
      release_wide.pop
      wide_connection.commit_db_transaction
    rescue StandardError => error
      item_finished << { wide_error: error }
      wide_connection.rollback_db_transaction if wide_connection.transaction_open?
    end
    @threads << wide

    wide_inserted.pop

    item = Thread.new do
      item_connection.execute("SET lock_timeout = '15s'")
      item_connection.execute(insert_sql(item_connection, item_id: @item.id, wording: "Stay fee."))
      item_finished << { inserted: true }
    rescue StandardError => error
      item_finished << { error: error }
    end
    @threads << item

    wait_until_ungranted_lock!
    release_wide << true

    unless wide.join(8)
      flunk "timed out waiting for the agreement-wide insert to commit"
    end
    outcome = item_finished.pop
    unless item.join(8)
      flunk "timed out waiting for the Item-scoped insert"
    end

    assert_nil outcome[:wide_error], outcome[:wide_error]&.message
    assert_nil outcome[:inserted]
    assert_kind_of ActiveRecord::StatementInvalid, outcome[:error]
    assert_match(/both Item scope and agreement-wide scope/, outcome[:error].message)
    rows = SupplierAgreementReference.where(supplier_arrangement_version_id: @version.id, kind: "destination_fee")
    assert_equal 1, rows.count
    assert_nil rows.sole.arrangement_item_id
  end

  private

  def insert_sql(connection, item_id:, wording:)
    item_sql = item_id.nil? ? "NULL" : connection.quote(item_id)
    <<~SQL.squish
      INSERT INTO supplier_agreement_references (
        id, agency_id, departure_id, supplier_arrangement_id,
        supplier_arrangement_version_id, arrangement_item_id, kind,
        governing_wording, source_description, recorded_by_id, recorded_at,
        lock_version, created_at, updated_at
      ) VALUES (
        #{connection.quote(SecureRandom.uuid_v7)},
        #{connection.quote(@agency.id)},
        #{connection.quote(@departure.id)},
        #{connection.quote(@arrangement.id)},
        #{connection.quote(@version.id)},
        #{item_sql},
        'destination_fee',
        #{connection.quote(wording)},
        'Hilton agreement',
        #{connection.quote(@admin.id)},
        NOW(),
        0,
        NOW(),
        NOW()
      )
    SQL
  end

  def wait_until_ungranted_lock!(timeout_seconds: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
    ActiveRecord::Base.connection.uncached do
      loop do
        waiting = ActiveRecord::Base.connection.select_value(<<~SQL).to_i
          SELECT COUNT(*)
          FROM pg_locks
          WHERE NOT granted
        SQL
        return if waiting.positive?

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          flunk "timed out waiting for the Item-scoped insert to block on the version lock"
        end
        sleep 0.01
      end
    end
  end
end
