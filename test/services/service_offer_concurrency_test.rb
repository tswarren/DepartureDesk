require "test_helper"

class ServiceOfferConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M4A race #{suffix}", workspace_code: "o#{suffix}",
      country_code: "US", default_currency: "USD", default_timezone: "UTC",
      office_name: "Race Office", office_code: "RACE", office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race", administrator_last_name: "Planner",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m4a-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @supplier = create_capacity_supplier(@agency, "Race Offer Supplier")
    @departure = create_capacity_departure(@agency, name: "Offer race")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "RaceOffer", capacity_management: "unmanaged"
    )
    SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @graph[:arrangement],
      supplier_arrangement_version: @graph[:version],
      arrangement_item: @graph[:item], charging_supplier: @supplier,
      label: "Race cost", position: 1
    ).then do |source|
      SupplierCostDefinition.create!(
        agency: @agency, departure: @departure,
        supplier_arrangement: @graph[:arrangement],
        supplier_arrangement_version: @graph[:version],
        supplier_cost_source: source, stage: "contracted",
        status: "forecast_ready", mode: "zero_cost",
        zero_cost_reason: "Included", currency: "USD",
        forecast_ready_by: @actor, forecast_ready_at: Time.current,
        readiness_fingerprint: "sha256:m4a-race", readiness_provenance: "Signed"
      )
    end
    SupplierCommitmentTriggerDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @graph[:arrangement],
      supplier_arrangement_version: @graph[:version],
      committed_supplier: @supplier,
      trigger_kind: "arrangement_confirmation",
      authority_shape: "fixed_quantity",
      description: "Race trigger",
      fixed_quantity: 1, quantity_basis: "resource_units", position: 1
    )
  end

  teardown do
    agency_id = @agency&.id
    next unless agency_id

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      %w[
        service_offer_source_bindings service_offer_definitions service_offer_versions service_offers
        supplier_confirmation_commitment_links supplier_confirmation_capacity_event_links
        supplier_confirmation_identifier_links supplier_confirmation_activation_links
        supplier_commitments supplier_arrangement_activation_capacity_entries
        supplier_arrangement_activation_cost_selections supplier_arrangement_activations
        supplier_issued_identifiers supplier_confirmations
        supplier_commitment_trigger_definitions agency_command_idempotency_keys
        supplier_cost_definitions supplier_cost_sources
        capacity_pool_definitions capacity_pair_definitions capacity_pools
        service_occurrence_definitions supplier_resource_definitions arrangement_item_definitions
        service_occurrences supplier_resources arrangement_items
        supplier_arrangement_versions supplier_arrangements
      ].each do |table|
        ActiveRecord::Base.connection.execute(
          "DELETE FROM #{table} WHERE agency_id = #{ActiveRecord::Base.connection.quote(agency_id)}"
        )
      end
    end
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "create from source versus arrangement activation has no deadlock or half-written offer" do
    arrangement_lock = @graph[:arrangement].lock_version
    version_lock = @graph[:version].lock_version
    outcomes = race do |index|
      if index.zero?
        ActivateSupplierArrangementVersion.new(
          agency: @agency, actor: @actor, arrangement: @graph[:arrangement],
          version: @graph[:version],
          arrangement_lock_version: arrangement_lock,
          version_lock_version: version_lock,
          idempotency_key: SecureRandom.uuid,
          evidence_attributes: {
            evidence_kind: "supplier_confirmation", evidence_on: Date.current,
            channel: "portal", reference_note: "Race activation",
            confirmed_without_identifier_reason: "None"
          },
          cost_source_coverage_acknowledged: true,
          provisional_costs_acknowledged: true,
          commitment_trigger_coverage_acknowledged: true
        ).call
      else
        CreateServiceOfferFromSource.new(
          agency: @agency, actor: @actor, departure: @departure,
          idempotency_key: SecureRandom.uuid,
          attributes: {
            supplier_arrangement_id: @graph[:arrangement].id,
            supplier_arrangement_version_id: @graph[:version].id,
            arrangement_item_id: @graph[:item].id,
            client_title: "Race cabin"
          }
        ).call
      end
    end

    outcomes.each do |outcome|
      next if outcome.is_a?(AgencyCommand::Result)
      next if outcome.is_a?(AgencyCommand::Error) &&
        %i[invalid invalid_state conflict].include?(outcome.code)

      raise outcome
    end

    @departure.service_offers.find_each do |offer|
      version = offer.versions.sole
      assert_not_nil version.definition
      assert version.source_bindings.any?
    end
    arrangement = @graph[:arrangement].reload
    assert_includes %w[draft active], arrangement.status
  end

  private

  def race
    ready = Queue.new
    release = Queue.new
    threads = 2.times.map do |index|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          yield index
        end
      rescue StandardError => error
        error
      end
    end
    2.times { ready.pop }
    2.times { release << true }
    threads.map(&:value)
  end
end
