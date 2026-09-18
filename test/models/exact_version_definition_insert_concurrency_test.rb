require "test_helper"

class ExactVersionDefinitionInsertConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Def Insert Race #{suffix}",
      workspace_code: "d#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race",
      administrator_last_name: "Admin",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:def-insert-#{suffix}"
    ).call.record
    @admin = @agency.agency_users.sole
    @office = @agency.offices.sole
    @departure = @agency.departures.create!(
      name: "Definition insert race #{suffix}",
      starts_on: Date.new(2027, 9, 1),
      ends_on: Date.new(2027, 9, 2),
      time_zone: "UTC",
      operating_currency: "USD",
      responsible_office: @office,
      responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-#{SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")}",
      display_name: "Definition Insert Race Supplier #{suffix}"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: "Definition insert race arrangement #{suffix}"
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
    ArrangementItemDefinition.where(agency_id: agency_id).delete_all
    ArrangementItem.where(agency_id: agency_id).delete_all
    SupplierArrangementVersion.where(agency_id: agency_id).delete_all
    SupplierArrangement.where(agency_id: agency_id).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent insert waits for activation lock and is rejected afterward" do
    version_id = @version.id
    activator_locked = Queue.new
    release_activation = Queue.new
    insert_finished = Queue.new

    activator_connection = ActiveRecord::Base.connection_pool.checkout
    inserter_connection = ActiveRecord::Base.connection_pool.checkout
    @leased_connections = [ activator_connection, inserter_connection ]

    activator = Thread.new do
      activator_connection.begin_db_transaction
      activator_connection.execute(<<~SQL.squish)
        SELECT id FROM supplier_arrangement_versions
        WHERE id = #{activator_connection.quote(version_id)}
        FOR UPDATE
      SQL
      activator_locked << true
      release_activation.pop
      activator_connection.execute(<<~SQL.squish)
        UPDATE supplier_arrangement_versions
        SET status = 'activated', activated_at = NOW()
        WHERE id = #{activator_connection.quote(version_id)}
      SQL
      activator_connection.commit_db_transaction
    rescue StandardError => error
      insert_finished << { activator_error: error }
      activator_connection.rollback_db_transaction if activator_connection.transaction_open?
    end
    @threads << activator

    activator_locked.pop

    inserter = Thread.new do
      inserter_connection.execute("SET lock_timeout = '15s'")
      inserter_connection.execute(<<~SQL.squish)
        INSERT INTO arrangement_item_definitions (
          id, agency_id, departure_id, supplier_arrangement_id,
          supplier_arrangement_version_id, arrangement_item_id,
          name, category, position, created_at, updated_at
        ) VALUES (
          #{inserter_connection.quote(SecureRandom.uuid_v7)},
          #{inserter_connection.quote(@agency.id)},
          #{inserter_connection.quote(@departure.id)},
          #{inserter_connection.quote(@arrangement.id)},
          #{inserter_connection.quote(version_id)},
          #{inserter_connection.quote(@item.id)},
          'Smuggled concurrent item',
          'lodging',
          99,
          NOW(),
          NOW()
        )
      SQL
      insert_finished << { inserted: true }
    rescue StandardError => error
      insert_finished << { error: error }
    end
    @threads << inserter

    wait_until_ungranted_lock!
    release_activation << true

    unless activator.join(8)
      flunk "timed out waiting for activation transaction"
    end

    outcome = insert_finished.pop
    unless inserter.join(8)
      flunk "timed out waiting for concurrent definition insert"
    end

    assert_nil outcome[:activator_error], outcome[:activator_error]&.message
    assert_nil outcome[:inserted]
    assert_kind_of ActiveRecord::StatementInvalid, outcome[:error]
    assert_match(/immutable after leaving draft/i, outcome[:error].message)
    assert_equal "activated", @version.reload.status
    assert_equal 0, ArrangementItemDefinition.where(supplier_arrangement_version_id: version_id).count
  end

  private

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
          flunk "timed out waiting for concurrent INSERT to block on the version lock"
        end
        sleep 0.01
      end
    end
  end
end
