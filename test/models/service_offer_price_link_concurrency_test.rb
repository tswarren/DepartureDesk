require "test_helper"

class ServiceOfferPriceLinkConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "Offer Price Link Race #{suffix}",
      workspace_code: "p#{suffix}",
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
      actor_identifier: "test:offer-price-link-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @office = @agency.offices.sole
    @departure = @agency.departures.create!(
      name: "Offer price link race #{suffix}",
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
      attributes: { client_title: "Link race offer", fulfillment_basis: "on_request" }
    ).call.record
    @version = @offer.editable_draft_version
    @definition = @version.create_price_definition!(
      agency: @agency, departure: @departure, service_offer: @offer,
      currency: "USD", mode: "calculated"
    )
    @fare = insert_component(
      @definition, label: "Fare", calculation_kind: "fixed",
      amount_minor_units: 10_000, quantity_basis: "service_instances", position: 1
    )
    @percentage = insert_component(
      @definition, label: "Tax", client_role: "tax_fee", calculation_kind: "percentage",
      amount_minor_units: nil, rate: 0.1, percentage_treatment: "additive",
      quantity_basis: nil, position: 2
    )
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
    ServiceOfferPriceComponentBase.where(agency_id: agency_id).delete_all
    ServiceOfferPriceComponent.where(agency_id: agency_id).delete_all
    ServiceOfferPriceDefinition.where(agency_id: agency_id).delete_all
    ServiceOfferDefinition.where(agency_id: agency_id).delete_all
    ServiceOfferVersion.where(agency_id: agency_id).delete_all
    ServiceOffer.where(agency_id: agency_id).delete_all
    AgencyCommandIdempotencyKey.where(agency_id: agency_id).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  ensure
    ActiveRecord::Base.connection.execute("SET session_replication_role = DEFAULT")
  end

  test "concurrent position change and link insert cannot commit a forward base" do
    fare_id = @fare.id
    percentage_id = @percentage.id
    definition_id = @definition.id
    mover_locked = Queue.new
    release_mover = Queue.new
    insert_finished = Queue.new

    mover_connection = ActiveRecord::Base.connection_pool.checkout
    inserter_connection = ActiveRecord::Base.connection_pool.checkout
    @leased_connections = [ mover_connection, inserter_connection ]

    mover = Thread.new do
      mover_connection.begin_db_transaction
      mover_connection.execute(<<~SQL.squish)
        UPDATE service_offer_price_components
        SET position = 4, updated_at = NOW()
        WHERE id = #{mover_connection.quote(fare_id)}
      SQL
      mover_locked << true
      release_mover.pop
      mover_connection.commit_db_transaction
    rescue StandardError => error
      insert_finished << { mover_error: error }
      mover_connection.rollback_db_transaction if mover_connection.transaction_open?
    end
    @threads << mover

    mover_locked.pop

    inserter = Thread.new do
      inserter_connection.execute("SET lock_timeout = '15s'")
      inserter_connection.execute(<<~SQL.squish)
        INSERT INTO service_offer_price_component_bases (
          id, agency_id, departure_id, service_offer_id, service_offer_version_id,
          service_offer_price_definition_id, service_offer_price_component_id,
          base_component_id, direction, position, created_at, updated_at
        ) VALUES (
          #{inserter_connection.quote(SecureRandom.uuid_v7)},
          #{inserter_connection.quote(@agency.id)},
          #{inserter_connection.quote(@departure.id)},
          #{inserter_connection.quote(@offer.id)},
          #{inserter_connection.quote(@version.id)},
          #{inserter_connection.quote(definition_id)},
          #{inserter_connection.quote(percentage_id)},
          #{inserter_connection.quote(fare_id)},
          'add',
          1,
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
    release_mover << true

    unless mover.join(8)
      flunk "timed out waiting for position-change transaction"
    end

    outcome = insert_finished.pop
    unless inserter.join(8)
      flunk "timed out waiting for concurrent base-link insert"
    end

    assert_nil outcome[:mover_error], outcome[:mover_error]&.message
    assert_nil outcome[:inserted]
    assert_kind_of ActiveRecord::StatementInvalid, outcome[:error]
    assert_match(/earlier component/i, outcome[:error].message)
    assert_equal 4, @fare.reload.position
    assert_equal 0, ServiceOfferPriceComponentBase.where(service_offer_price_definition_id: definition_id).count
  end

  private

  def insert_component(definition, **attrs)
    now = Time.current
    row = {
      id: SecureRandom.uuid_v7,
      agency_id: @agency.id,
      departure_id: @departure.id,
      service_offer_id: @offer.id,
      service_offer_version_id: definition.service_offer_version_id,
      service_offer_price_definition_id: definition.id,
      label: attrs.delete(:label) || "Component",
      client_role: attrs.delete(:client_role) || "base_price",
      calculation_kind: attrs[:calculation_kind] || "unit_rate",
      amount_minor_units: attrs[:amount_minor_units],
      rate: attrs[:rate],
      quantity_basis: attrs.key?(:quantity_basis) ? attrs[:quantity_basis] : "persons",
      percentage_treatment: attrs[:percentage_treatment],
      position: attrs.delete(:position) || (definition.service_offer_price_components.maximum(:position).to_i + 1),
      created_at: now,
      updated_at: now
    }
    ServiceOfferPriceComponent.insert!(row)
    ServiceOfferPriceComponent.find(row[:id])
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
          flunk "timed out waiting for concurrent INSERT to block on the component lock"
        end
        sleep 0.01
      end
    end
  end
end
