# frozen_string_literal: true

require "test_helper"

class M3f1DefinitionReviewPreloadTest < ActiveSupport::TestCase
  include CapacityGraphHelper
  include M3CCostScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @supplier = create_capacity_supplier(@agency, "M3F.1 Review Supplier")
    @departure = create_capacity_departure(@agency, name: "M3F.1 Review Departure")
    @graph = create_capacity_graph(
      agency: @agency, departure: @departure, contractor: @supplier, provider: @supplier,
      prefix: "M3F1 Review", capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @item = @graph[:item]
  end

  test "definition review bundle evaluates forecast and occupancy in one preload" do
    category = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @admin, arrangement_item: @item,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Anonymous occupant" }
    ).call.record
    assumption = CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, arrangement_item: @item,
      idempotency_key: SecureRandom.uuid, attributes: {}
    ).call.record
    CreateSupplierCostOccupancyProfile.new(
      agency: @agency, actor: @admin, assumption: assumption,
      assumption_lock_version: assumption.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Double", resource_unit_count: 1 },
      positions: [ category.id, category.id ]
    ).call.record

    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: @item.id, charging_supplier_id: @supplier.id, label: "Cabin"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source,
      source_lock_version: source.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      }
    ).call.record
    CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "First/second fare", economic_role: "supplier_charge",
        calculation_kind: "unit_rate",
        amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:first_second_fare),
        quantity_basis: "occupancy_positions", occupancy_position_from: 1, occupancy_position_to: 2,
        position: 1, pass_through: false
      }
    ).call.record

    assumption = SupplierCostUsageAssumption.includes(:supplier_cost_occupancy_profiles)
      .find(assumption.id)

    preload_calls = 0
    EvaluateSupplierCostForecast.class_eval do
      alias_method :preload_without_count!, :preload!
      define_method(:preload!) do
        preload_calls += 1
        preload_without_count!
      end
    end

    begin
      bundle = EvaluateSupplierCostForecast.new(
        agency: @agency, departure: @departure, arrangement: @arrangement,
        probe_definition: definition
      ).call_for_definition_review(source: source, assumption: assumption)

      assert_equal 1, preload_calls
      assert bundle.forecast.arrangements.any?
      assert_predicate bundle.occupancy_preview.profiles, :any?

      wrapped = EvaluateSupplierCostOccupancyPreview.new(
        agency: @agency, departure: @departure, arrangement: @arrangement,
        source: source, definition: definition, assumption: assumption,
        item_definition: @graph[:item_definition]
      ).call(precomputed: bundle.occupancy_preview)

      assert_equal 1, preload_calls
      assert wrapped.applicable
      assert_nil wrapped.empty_reason
    ensure
      EvaluateSupplierCostForecast.class_eval do
        alias_method :preload!, :preload_without_count!
        remove_method :preload_without_count!
      end
    end
  end
end
