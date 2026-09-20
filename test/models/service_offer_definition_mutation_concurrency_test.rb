require "test_helper"

class ServiceOfferDefinitionMutationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Offer Freeze Race #{suffix}",
      workspace_code: "f#{suffix}",
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
      actor_identifier: "test:offer-freeze-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @office = @agency.offices.sole
    @departure = @agency.departures.create!(
      name: "Offer freeze race #{suffix}",
      starts_on: Date.new(2027, 9, 1),
      ends_on: Date.new(2027, 9, 2),
      time_zone: "UTC",
      operating_currency: "USD",
      responsible_office: @office,
      responsible_agency_user: @actor
    )
    @offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency,
      actor: @actor,
      departure: @departure,
      idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Original freeze title", fulfillment_basis: "on_request" }
    ).call.record
    @version = @offer.editable_draft_version
    @definition = @version.definition
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
    ServiceOfferSourceBinding.where(agency_id: agency_id).delete_all
    ServiceOfferDefinition.where(agency_id: agency_id).delete_all
    ServiceOfferVersion.where(agency_id: agency_id).delete_all
    ServiceOffer.where(agency_id: agency_id).delete_all
    AgencyCommandIdempotencyKey.where(agency_id: agency_id).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent definition update waits for discard lock and is rejected afterward" do
    version_id = @version.id
    definition_id = @definition.id
    discarder_locked = Queue.new
    release_discard = Queue.new
    update_finished = Queue.new

    discarder_connection = ActiveRecord::Base.connection_pool.checkout
    editor_connection = ActiveRecord::Base.connection_pool.checkout
    @leased_connections = [ discarder_connection, editor_connection ]

    discarder = Thread.new do
      discarder_connection.begin_db_transaction
      discarder_connection.execute(<<~SQL.squish)
        SELECT id FROM service_offer_versions
        WHERE id = #{discarder_connection.quote(version_id)}
        FOR UPDATE
      SQL
      discarder_locked << true
      release_discard.pop
      discarder_connection.execute(<<~SQL.squish)
        UPDATE service_offer_versions
        SET status = 'abandoned',
            abandoned_at = NOW(),
            abandoned_reason = 'Concurrent freeze proof',
            updated_at = NOW()
        WHERE id = #{discarder_connection.quote(version_id)}
      SQL
      discarder_connection.commit_db_transaction
    rescue StandardError => error
      update_finished << { discarder_error: error }
      discarder_connection.rollback_db_transaction if discarder_connection.transaction_open?
    end
    @threads << discarder

    discarder_locked.pop

    editor = Thread.new do
      editor_connection.execute("SET lock_timeout = '15s'")
      editor_connection.execute(<<~SQL.squish)
        UPDATE service_offer_definitions
        SET client_title = 'Smuggled concurrent title', updated_at = NOW()
        WHERE id = #{editor_connection.quote(definition_id)}
      SQL
      update_finished << { updated: true }
    rescue StandardError => error
      update_finished << { error: error }
    end
    @threads << editor

    wait_until_ungranted_lock!
    release_discard << true

    unless discarder.join(8)
      flunk "timed out waiting for discard transaction"
    end

    outcome = update_finished.pop
    unless editor.join(8)
      flunk "timed out waiting for concurrent definition update"
    end

    assert_nil outcome[:discarder_error], outcome[:discarder_error]&.message
    assert_nil outcome[:updated]
    assert_kind_of ActiveRecord::StatementInvalid, outcome[:error]
    assert_match(/immutable after leaving draft/i, outcome[:error].message)
    assert_equal "abandoned", @version.reload.status
    assert_equal "Original freeze title", @definition.reload.client_title
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
          flunk "timed out waiting for concurrent UPDATE to block on the version lock"
        end
        sleep 0.01
      end
    end
  end
end
