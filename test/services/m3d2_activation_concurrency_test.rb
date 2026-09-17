require "test_helper"

class M3d2ActivationConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M3D2 race #{suffix}", workspace_code: "a#{suffix}",
      country_code: "US", default_currency: "USD", default_timezone: "UTC",
      office_name: "Race Office", office_code: "RACE", office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race", administrator_last_name: "Planner",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m3d2-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @supplier = create_capacity_supplier(@agency, "Race Supplier")
    @departure = create_capacity_departure(@agency, name: "Activation race")
    @departure.update!(
      status: "active", departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure,
      contractor: @supplier, provider: @supplier,
      prefix: "Race", capacity_management: "unmanaged"
    )
    source = SupplierCostSource.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @graph[:arrangement],
      supplier_arrangement_version: @graph[:version],
      arrangement_item: @graph[:item], charging_supplier: @supplier,
      label: "Race cost", position: 1
    )
    SupplierCostDefinition.create!(
      agency: @agency, departure: @departure,
      supplier_arrangement: @graph[:arrangement],
      supplier_arrangement_version: @graph[:version],
      supplier_cost_source: source, stage: "contracted",
      status: "forecast_ready", mode: "zero_cost",
      zero_cost_reason: "Included", currency: "USD",
      forecast_ready_by: @actor, forecast_ready_at: Time.current,
      readiness_fingerprint: "sha256:race", readiness_provenance: "Signed"
    )
  end

  teardown do
    agency_id = @agency&.id
    next unless agency_id

    ActiveRecord::Base.transaction do
      ActiveRecord::Base.connection.execute("SET LOCAL session_replication_role = replica")
      %w[
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

  test "first activation versus ordinary Supplier inactivation has one coherent winner" do
    arrangement_lock = @graph[:arrangement].lock_version
    version_lock = @graph[:version].lock_version
    supplier_lock = @supplier.lock_version
    outcomes = race do |index|
      if index.zero?
        ActivateSupplierArrangementVersion.new(
          agency: Agency.find(@agency.id), actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@graph[:arrangement].id),
          version: SupplierArrangementVersion.find(@graph[:version].id),
          arrangement_lock_version: arrangement_lock,
          version_lock_version: version_lock,
          idempotency_key: "activation-status-race",
          evidence_attributes: {
            evidence_kind: "supplier_confirmation", evidence_on: Date.current,
            channel: "portal", reference_note: "Race confirmation",
            confirmed_without_identifier_reason: "No identifier"
          },
          cost_source_coverage_acknowledged: true,
          commitment_trigger_coverage_acknowledged: true
        ).call
      else
        ChangeSupplierStatus.new(
          agency: Agency.find(@agency.id), actor: AgencyUser.find(@actor.id),
          supplier: Supplier.find(@supplier.id), status: "inactive",
          lock_version: supplier_lock
        ).call
      end
    end

    @supplier.reload
    @graph[:arrangement].reload
    if @supplier.inactive?
      assert_equal "draft", @graph[:arrangement].status
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :invalid
    else
      assert_equal "active", @graph[:arrangement].status
      assert_includes outcomes.grep(AgencyCommand::Error).map(&:code), :dependency_exists
    end
    assert_equal 1, outcomes.grep(AgencyCommand::Result).size
  end

  test "two successor activations produce one atomic governing transition" do
    first = activation_command(
      version: @graph[:version],
      idempotency_key: "first-before-successor-race"
    ).call.record
    predecessor = @graph[:version].reload
    successor = CreateSupplierArrangementSuccessor.new(
      agency: @agency,
      actor: @actor,
      arrangement: @graph[:arrangement].reload,
      arrangement_lock_version: @graph[:arrangement].lock_version,
      version_lock_version: predecessor.lock_version,
      idempotency_key: "create-successor-race"
    ).call.record
    arrangement_lock = @graph[:arrangement].reload.lock_version
    version_lock = successor.lock_version

    outcomes = race do |index|
      activation_command(
        version: SupplierArrangementVersion.find(successor.id),
        idempotency_key: "successor-race-#{index}",
        arrangement_lock_version: arrangement_lock,
        version_lock_version: version_lock
      ).call
    end

    assert_equal 1, outcomes.grep(AgencyCommand::Result).size
    assert_equal 1, outcomes.grep(AgencyCommand::Error).size
    assert_equal "superseded", predecessor.reload.status
    assert_equal "activated", successor.reload.status
    assert_equal successor.id, @graph[:arrangement].reload.governing_version_id
    assert_equal 2, @graph[:arrangement].supplier_arrangement_activations.count
    assert_equal first.id,
      successor.supplier_arrangement_activation.predecessor_activation_id
  end

  private

  def activation_command(
    version:, idempotency_key:, arrangement_lock_version: nil, version_lock_version: nil
  )
    ActivateSupplierArrangementVersion.new(
      agency: Agency.find(@agency.id),
      actor: AgencyUser.find(@actor.id),
      arrangement: SupplierArrangement.find(@graph[:arrangement].id),
      version: version,
      arrangement_lock_version: arrangement_lock_version ||
        @graph[:arrangement].reload.lock_version,
      version_lock_version: version_lock_version || version.reload.lock_version,
      idempotency_key: idempotency_key,
      evidence_attributes: {
        evidence_kind: "supplier_confirmation",
        evidence_on: Date.current,
        channel: "portal",
        reference_note: "Race confirmation #{idempotency_key}",
        confirmed_without_identifier_reason: "No identifier"
      },
      cost_source_coverage_acknowledged: true,
      commitment_trigger_coverage_acknowledged: true
    )
  end

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
    outcomes = threads.map(&:value)
    outcomes.each do |outcome|
      next if outcome.is_a?(AgencyCommand::Result)
      next if outcome.is_a?(AgencyCommand::Error) &&
        %i[invalid invalid_state dependency_exists].include?(outcome.code)

      raise outcome
    end
    outcomes
  end
end
