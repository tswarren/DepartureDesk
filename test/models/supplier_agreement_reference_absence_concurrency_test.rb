# frozen_string_literal: true

require "test_helper"

class SupplierAgreementReferenceAbsenceConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Absence Race #{suffix}",
      workspace_code: "a#{suffix}",
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
      actor_identifier: "test:absence-race-#{suffix}"
    ).call.record
    @admin = @agency.agency_users.sole
    @office = @agency.offices.sole
    @departure = @agency.departures.create!(
      name: "Absence race #{suffix}",
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
      display_name: "Absence Race Hotel #{suffix}"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: "Absence race arrangement #{suffix}"
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
    SupplierAgreementReferenceAbsence.where(agency_id: agency_id).delete_all
    SupplierAgreementReference.where(agency_id: agency_id).delete_all
    ArrangementItem.where(agency_id: agency_id).delete_all
    SupplierArrangementVersion.where(agency_id: agency_id).delete_all
    SupplierArrangement.where(agency_id: agency_id).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent opposite scopes across wording and reviewed none let exactly one commit" do
    race(
      first_sql: ->(connection) { reference_sql(connection, item_id: nil) },
      second_sql: ->(connection) { absence_sql(connection, item_id: @item.id) }
    )
    assert_equal 1, SupplierAgreementReference.where(supplier_arrangement_version_id: @version.id, kind: "cancellation").count
    assert_equal 0, SupplierAgreementReferenceAbsence.where(supplier_arrangement_version_id: @version.id, kind: "cancellation").count
  end

  test "concurrent item wording and reviewed none let exactly one commit" do
    race(
      first_sql: ->(connection) { reference_sql(connection, item_id: @item.id) },
      second_sql: ->(connection) { absence_sql(connection, item_id: @item.id) },
      message: /both wording and reviewed none/
    )
    assert_equal 1, SupplierAgreementReference.where(supplier_arrangement_version_id: @version.id, kind: "cancellation").count
    assert_equal 0, SupplierAgreementReferenceAbsence.where(supplier_arrangement_version_id: @version.id, kind: "cancellation").count
  end

  test "concurrent agreement-wide wording and reviewed none let exactly one commit" do
    race(
      first_sql: ->(connection) { reference_sql(connection, item_id: nil) },
      second_sql: ->(connection) { absence_sql(connection, item_id: nil) },
      message: /both wording and reviewed none/
    )
    assert_equal 1, SupplierAgreementReference.where(supplier_arrangement_version_id: @version.id, kind: "cancellation").count
    assert_equal 0, SupplierAgreementReferenceAbsence.where(supplier_arrangement_version_id: @version.id, kind: "cancellation").count
  end

  private

  def race(first_sql:, second_sql:, message: /both Item scope and agreement-wide scope/)
    first_inserted = Queue.new
    release_first = Queue.new
    second_finished = Queue.new
    first_connection = ActiveRecord::Base.connection_pool.checkout
    second_connection = ActiveRecord::Base.connection_pool.checkout
    @leased_connections = [ first_connection, second_connection ]

    first = Thread.new do
      first_connection.begin_db_transaction
      first_connection.execute(first_sql.call(first_connection))
      first_inserted << true
      release_first.pop
      first_connection.commit_db_transaction
    rescue StandardError => error
      second_finished << { first_error: error }
      first_connection.rollback_db_transaction if first_connection.transaction_open?
    end
    @threads << first
    first_inserted.pop

    second = Thread.new do
      second_connection.execute("SET lock_timeout = '15s'")
      second_connection.execute(second_sql.call(second_connection))
      second_finished << { inserted: true }
    rescue StandardError => error
      second_finished << { error: error }
    end
    @threads << second

    wait_until_ungranted_lock!
    release_first << true
    flunk "timed out waiting for the first insert to commit" unless first.join(8)
    outcome = second_finished.pop
    flunk "timed out waiting for the second insert" unless second.join(8)

    assert_nil outcome[:first_error], outcome[:first_error]&.message
    assert_nil outcome[:inserted]
    assert_kind_of ActiveRecord::StatementInvalid, outcome[:error]
    assert_match message, outcome[:error].message
  end

  def reference_sql(connection, item_id:)
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
        #{item_id.nil? ? "NULL" : connection.quote(item_id)},
        'cancellation',
        'Cancellation wording.',
        'Hilton agreement',
        #{connection.quote(@admin.id)},
        NOW(), 0, NOW(), NOW()
      )
    SQL
  end

  def absence_sql(connection, item_id:)
    <<~SQL.squish
      INSERT INTO supplier_agreement_reference_absences (
        id, agency_id, departure_id, supplier_arrangement_id,
        supplier_arrangement_version_id, arrangement_item_id, kind,
        recorded_by_id, recorded_at, lock_version, created_at, updated_at
      ) VALUES (
        #{connection.quote(SecureRandom.uuid_v7)},
        #{connection.quote(@agency.id)},
        #{connection.quote(@departure.id)},
        #{connection.quote(@arrangement.id)},
        #{connection.quote(@version.id)},
        #{item_id.nil? ? "NULL" : connection.quote(item_id)},
        'cancellation',
        #{connection.quote(@admin.id)},
        NOW(), 0, NOW(), NOW()
      )
    SQL
  end

  def wait_until_ungranted_lock!(timeout_seconds: 5)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout_seconds
    ActiveRecord::Base.connection.uncached do
      loop do
        waiting = ActiveRecord::Base.connection.select_value(<<~SQL).to_i
          SELECT COUNT(*) FROM pg_locks WHERE NOT granted
        SQL
        return if waiting.positive?

        if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
          flunk "timed out waiting for the second insert to block on the version lock"
        end
        sleep 0.01
      end
    end
  end
end
