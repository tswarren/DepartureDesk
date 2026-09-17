require "test_helper"

class M3D0CompositeRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    suffix = SecureRandom.hex(4)
    @agency = ProvisionAgency.new(
      name: "M3D0 race #{suffix}",
      workspace_code: "m#{suffix}",
      country_code: "US",
      default_currency: "USD",
      default_timezone: "UTC",
      office_name: "Race Office",
      office_code: "RACE",
      office_timezone: "UTC",
      administrator_email: "admin-#{suffix}@example.test",
      administrator_first_name: "Race",
      administrator_last_name: "Planner",
      administrator_password: TEST_PASSWORD,
      actor_identifier: "test:m3d0-#{suffix}"
    ).call.record
    @actor = @agency.agency_users.sole
    @departure = create_capacity_departure(@agency, name: "M3D.0 composite race")
    @contractor = create_capacity_supplier(@agency, "Race contractor")
    @provider = create_capacity_supplier(@agency, "Race provider")
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @contractor,
      name: "Race arrangement"
    )
    @version = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
  end

  teardown do
    next unless @agency&.persisted?

    agency_id = @agency.id
    ArrangementItemSetupResult.where(agency_id:).delete_all
    AgencyCommandIdempotencyKey.where(agency_id:).delete_all
    SupplierCostComponentBase.where(agency_id:).delete_all
    SupplierCostComponent.where(agency_id:).delete_all
    SupplierCostDefinition.where(agency_id:).delete_all
    SupplierCostUsageAssumption.where(agency_id:).delete_all
    SupplierCostSource.where(agency_id:).delete_all
    CapacityPoolDefinition.where(agency_id:).delete_all
    CapacityPairDefinition.where(agency_id:).delete_all
    CapacityPool.where(agency_id:).delete_all
    ServiceOccurrenceDefinition.where(agency_id:).delete_all
    SupplierResourceDefinition.where(agency_id:).delete_all
    ArrangementItemDefinition.where(agency_id:).delete_all
    ServiceOccurrence.where(agency_id:).delete_all
    SupplierResource.where(agency_id:).delete_all
    ArrangementItem.where(agency_id:).delete_all
    SupplierArrangementVersion.where(agency_id:).delete_all
    SupplierArrangement.where(agency_id:).delete_all
    M1DirectoryScenario.cleanup!(@agency)
  end

  test "guided Item setup races a competing draft Item mutation without partial children" do
    submitted_lock = @version.lock_version
    outcomes = race(
      setup: -> {
        CreateArrangementItemSetup.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@arrangement.id),
          version_lock_version: submitted_lock,
          idempotency_key: "race-item-setup",
          item_attributes: { name: "Celebrity cabin", category: "lodging" },
          occurrence_attributes: {
            name: "Celebrity sailing", starts_on: "2026-06-01", ends_on: "2026-06-01"
          },
          resource_attributes: { name: "O1 cabin" }
        ).call
      },
      competing: -> {
        CreateArrangementItem.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@arrangement.id),
          version_lock_version: submitted_lock,
          idempotency_key: "race-competing-item",
          attributes: { name: "Competing Item", category: "other", other_category_label: "Other" }
        ).call
      }
    )

    assert_one_conflict(outcomes)
    setup_won = outcomes[:setup].is_a?(AgencyCommand::Result)
    assert_equal setup_won ? 1 : 0, ServiceOccurrence.where(agency: @agency).count
    assert_equal setup_won ? 1 : 0, SupplierResource.where(agency: @agency).count
    assert_equal 1, ArrangementItem.where(agency: @agency).count
  end

  test "bulk classification races a competing Resource mutation on the version lock" do
    graph = create_race_graph("Transfers")
    submitted_lock = graph[:version].lock_version
    outcomes = race(
      bulk: -> {
        BulkClassifyCapacityPairs.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          item: ArrangementItem.find(graph[:item].id),
          decisions: [ {
            service_occurrence_id: graph[:occurrence].id,
            supplier_resource_id: graph[:resource].id,
            classification: "not_applicable"
          } ],
          version_lock_version: submitted_lock,
          idempotency_key: "race-bulk"
        ).call
      },
      competing: -> {
        CreateSupplierResource.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          item: ArrangementItem.find(graph[:item].id),
          version_lock_version: submitted_lock,
          idempotency_key: "race-bulk-resource",
          attributes: { name: "Competing transfer vehicle" }
        ).call
      }
    )

    assert_one_conflict(outcomes)
    assert_equal outcomes[:bulk].is_a?(AgencyCommand::Result) ? 1 : 0,
      CapacityPairDefinition.where(agency: @agency).count
  end

  test "classify plus Pool races a competing Resource mutation atomically" do
    graph = create_race_graph("Hilton")
    submitted_lock = graph[:version].lock_version
    outcomes = race(
      pool: -> {
        ConfigureCapacityPairWithPool.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          item: ArrangementItem.find(graph[:item].id),
          service_occurrence: ServiceOccurrence.find(graph[:occurrence].id),
          supplier_resource: SupplierResource.find(graph[:resource].id),
          pool_attributes: {
            inventory_mode: "block",
            measurement_basis: "resource_units",
            label: "Hilton room block",
            unit_label: "rooms",
            proposed_opening_quantity: 8,
            evidence_kind: "contract",
            evidence_on: "2026-05-01",
            evidence_reference_note: "Supplier contract"
          },
          version_lock_version: submitted_lock,
          idempotency_key: "race-pool"
        ).call
      },
      competing: -> {
        CreateSupplierResource.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          item: ArrangementItem.find(graph[:item].id),
          version_lock_version: submitted_lock,
          idempotency_key: "race-pool-resource",
          attributes: { name: "Competing room type" }
        ).call
      }
    )

    assert_one_conflict(outcomes)
    pool_won = outcomes[:pool].is_a?(AgencyCommand::Result)
    assert_equal pool_won ? 1 : 0, CapacityPairDefinition.where(agency: @agency).count
    assert_equal pool_won ? 1 : 0, CapacityPool.where(agency: @agency).count
    assert_equal pool_won ? 1 : 0, CapacityPoolDefinition.where(agency: @agency).count
  end

  test "initial cost setup races forced Supplier inactivation without partial cost rows" do
    submitted_lock = @version.lock_version
    outcomes = race(
      cost: -> {
        CreateSupplierCostSetup.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          arrangement: SupplierArrangement.find(@arrangement.id),
          source_attributes: {
            label: "Vineyard coach", charging_supplier_id: @provider.id
          },
          definition_attributes: {
            stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up"
          },
          component_attributes: {
            label: "Coach fixed cost", economic_role: "supplier_charge",
            calculation_kind: "fixed", amount: "1200.00", pass_through: false
          },
          version_lock_version: submitted_lock,
          idempotency_key: "race-cost"
        ).call
      },
      inactivate: -> {
        supplier = Supplier.find(@provider.id)
        ChangeSupplierStatus.new(
          agency: Agency.find(@agency.id),
          actor: AgencyUser.find(@actor.id),
          supplier: supplier,
          status: "inactive",
          lock_version: supplier.lock_version,
          force: true,
          force_reason: "Competing Supplier closure"
        ).call
      }
    )

    assert_instance_of AgencyCommand::Result, outcomes[:inactivate]
    cost_won = outcomes[:cost].is_a?(AgencyCommand::Result)
    assert_includes [ AgencyCommand::Result, AgencyCommand::Error ], outcomes[:cost].class
    assert_includes [ :invalid, :invalid_state ], outcomes[:cost].code unless cost_won
    assert_equal cost_won ? 1 : 0, SupplierCostSource.where(agency: @agency).count
    assert_equal cost_won ? 1 : 0, SupplierCostDefinition.where(agency: @agency).count
    assert_equal cost_won ? 1 : 0, SupplierCostComponent.where(agency: @agency).count
    assert_predicate @provider.reload, :inactive?
  end

  private

  def create_race_graph(prefix)
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    item_definition = @version.arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: item,
      name: "#{prefix} Item",
      category: "lodging",
      capacity_management: "managed",
      default_service_provider: @provider,
      position: 1
    )
    occurrence = item.service_occurrences.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement
    )
    @version.service_occurrence_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: item,
      service_occurrence: occurrence,
      name: "#{prefix} Occurrence",
      starts_on: @departure.starts_on,
      ends_on: @departure.starts_on,
      time_zone: "UTC",
      service_provider: @provider
    )
    resource = item.supplier_resources.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement
    )
    @version.supplier_resource_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: item,
      supplier_resource: resource,
      name: "#{prefix} Resource",
      position: 1
    )
    { version: @version, item:, item_definition:, occurrence:, resource: }
  end

  def race(**operations)
    ready = Queue.new
    release = Queue.new
    threads = operations.transform_values do |operation|
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          release.pop
          operation.call
        end
      rescue StandardError => error
        error
      end
    end
    operations.size.times { ready.pop }
    operations.size.times { release << true }
    threads.transform_values(&:value)
  end

  def assert_one_conflict(outcomes)
    results = outcomes.values.count { |outcome| outcome.is_a?(AgencyCommand::Result) }
    errors = outcomes.values.select { |outcome| outcome.is_a?(AgencyCommand::Error) }
    assert_equal 1, results, outcomes.inspect
    assert_equal 1, errors.size, outcomes.inspect
    assert_equal :conflict, errors.sole.code
  end
end
