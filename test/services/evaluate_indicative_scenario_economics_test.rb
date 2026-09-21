require "test_helper"

class EvaluateIndicativeScenarioEconomicsTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "attributed resource cost uses the bound source and does not persist assumptions" do
    cruise = m3f_activated_graph!(
      "M4B Celebrity econ",
      "Celebrity Beyond M4B econ",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    m3f_create_celebrity_o1_cost!(cruise)
    offer = create_priced_offer(
      cruise,
      title: "O1 illustrative",
      resource: true,
      pattern: "occupancy_positions",
      amount: "210.00"
    )
    assumption_count = SupplierCostUsageAssumption.where(agency: @agency).count

    result = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: {
        persons: 2, resource_units: 1,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call

    assert_equal :known, result.status
    assert_equal 42_000, result.client_revenue_minor_units
    assert_operator result.forecast_supplier_cost_minor_units, :>, 0
    assert_equal assumption_count, SupplierCostUsageAssumption.where(agency: @agency).count
    assert_not_equal EvaluateSupplierCostForecast.new(
      agency: @agency, departure: cruise[:departure], arrangement: cruise[:arrangement]
    ).call.totals.forecast_supplier_cost_minor_units, result.forecast_supplier_cost_minor_units
  end

  test "item-only binding does not pull a resource-scoped source" do
    cruise = m3f_activated_graph!(
      "M4B item pin",
      "Celebrity item pin",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    m3f_create_celebrity_o1_cost!(cruise)
    offer = create_priced_offer(
      cruise, title: "Item only", resource: false, occurrence: false,
      pattern: "per_person", amount: "200.00"
    )
    resource_ids = SupplierCostSource.where(label: "O1 cabin category").pluck(:id)
    result = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: { persons: 2, occupancy_positions: [ { key: "first" }, { key: "second" } ] }
    ).call
    assert (result.attributed_source_ids & resource_ids).empty?
  end

  test "vineyard coach stays unknown without enrollment and allocates with it" do
    graph = m3f_activated_graph!(
      "M4B Vineyard econ",
      "Vineyard Tour M4B econ",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    m3f_create_vineyard_costs!(graph)
    offer = create_priced_offer(
      graph, title: "Coach transfer", occurrence: false, resource: false,
      pattern: "per_person", amount: "90.00"
    )

    unknown = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: { persons: 2 }
    ).call
    assert_equal :unknown, unknown.status
    assert_match(/enrollment/i, unknown.reason)

    known = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: { persons: 2, enrollment_denominator: 30 }
    ).call
    assert_equal :known, known.status
    assert_equal "scenario economics", known.label
    assert_equal 18_000, known.client_revenue_minor_units
    assert_operator known.forecast_supplier_cost_minor_units, :<, 120_000
  end

  test "explicit-basis offer without sources is unknown" do
    departure = create_capacity_departure(@agency, name: "No source price")
    offer = CreateServiceOfferWithExplicitBasis.new(
      agency: @agency, actor: @actor, departure: departure, idempotency_key: SecureRandom.uuid,
      attributes: { client_title: "Insurance", fulfillment_basis: "on_request" }
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "fixed_per_service", amount: "25.00" }
    ).call
    result = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer, scenario: { service_instances: 1 }
    ).call
    assert_equal :unknown, result.status
  end

  test "two cabins expand one occupancy pattern for both price and cost" do
    cruise = m3f_activated_graph!(
      "M4B two cabin",
      "Celebrity two cabin",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    m3f_create_celebrity_o1_cost!(cruise)
    offer = create_priced_offer(
      cruise, title: "Two cabin O1", resource: true,
      pattern: "occupancy_positions", amount: "210.00"
    )
    one_cabin = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: {
        persons: 2, resource_units: 1,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call
    two_cabins = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: {
        persons: 4, resource_units: 2,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call

    assert_equal :known, one_cabin.status
    assert_equal :known, two_cabins.status
    assert_equal 84_000, two_cabins.client_revenue_minor_units
    assert_equal one_cabin.forecast_supplier_cost_minor_units * 2, two_cabins.forecast_supplier_cost_minor_units

    mismatch = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: {
        persons: 2, resource_units: 2,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call
    assert_equal :unknown, mismatch.status
    assert_match(/persons/i, mismatch.reason)

    expanded = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: {
        persons: 4, resource_units: 2,
        occupancy_positions: [ { key: "first" }, { key: "second" }, { key: "first" }, { key: "second" } ]
      }
    ).call
    assert_equal :unknown, expanded.status
    assert_match(/one resource/i, expanded.reason)
  end

  test "selected-stage participant category makes margin unknown and unused estimate does not" do
    graph = m3f_activated_graph!(
      "M4B category cost",
      "Category cost departure",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    category = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @actor, arrangement_item: graph[:item],
      version_lock_version: graph[:version].reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Adult occupant" }
    ).call.record
    create_persons_cost!(graph, stage: "contracted", participant_category: category)
    offer = create_priced_offer(
      graph, title: "Category scoped", occurrence: false, resource: false,
      pattern: "per_person", amount: "20.00"
    )
    unknown = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer, scenario: { persons: 2 }
    ).call
    assert_equal :unknown, unknown.status
    assert_match(/participant-category|category/i, unknown.reason)

    unscoped = m3f_activated_graph!(
      "M4B unused estimate",
      "Unused estimate departure",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    estimate_category = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @actor, arrangement_item: unscoped[:item],
      version_lock_version: unscoped[:version].reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Estimate occupant" }
    ).call.record
    source = create_persons_cost!(unscoped, stage: "contracted")
    create_persons_cost!(unscoped, stage: "estimate", participant_category: estimate_category, source: source)
    offer = create_priced_offer(
      unscoped, title: "Contracted wins", occurrence: false, resource: false,
      pattern: "per_person", amount: "20.00"
    )
    known = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer, scenario: { persons: 2 }
    ).call
    assert_equal :known, known.status, known.reason
  end

  test "alternative groups require exactly one in-offer selection" do
    graph = m3f_activated_graph!(
      "M4B alternatives",
      "Alternative sources",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    first = add_draft_item!(graph, "Alt A")
    second = add_draft_item!(graph, "Alt B")
    m3f_create_ready_cost!(first)
    m3f_create_ready_cost!(second)
    offer = create_priced_offer(
      graph, title: "Choose one dinner", occurrence: false, resource: false,
      pattern: "per_person", amount: "40.00"
    )
    left = AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: offer.editable_draft_version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: alternative_binding_attrs(first, "dinner")
    ).call.record
    right = AddServiceOfferSourceBinding.new(
      agency: @agency, actor: @actor, offer: offer,
      version_lock_version: offer.editable_draft_version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: alternative_binding_attrs(second, "dinner")
    ).call.record

    both = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer.reload,
      scenario: { persons: 2, selected_binding_ids: [ left.id, right.id ] }
    ).call
    assert_equal :unknown, both.status
    assert_match(/only one/i, both.reason)

    foreign = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: { persons: 2, selected_binding_ids: [ SecureRandom.uuid ] }
    ).call
    assert_equal :unknown, foreign.status
    assert_match(/not part of this service offer/i, foreign.reason)

    picked = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: offer,
      scenario: { persons: 2, selected_binding_ids: [ left.id ] }
    ).call
    assert_equal :known, picked.status, picked.reason
  end

  private

  def create_priced_offer(graph, title:, pattern:, amount:, occurrence: true, resource: false)
    attrs = {
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      client_title: title
    }
    attrs[:service_occurrence_id] = graph[:occurrence].id if occurrence
    attrs[:supplier_resource_id] = graph[:resource].id if resource
    offer = CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: graph[:departure],
      idempotency_key: SecureRandom.uuid, attributes: attrs
    ).call.record
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: pattern, amount: amount }
    ).call
    offer
  end

  def create_persons_cost!(graph, stage:, participant_category: nil, source: nil)
    actor = graph[:actor] || @actor
    source ||= CreateSupplierCostSource.new(
      agency: @agency, actor:, arrangement: graph[:arrangement],
      version_lock_version: graph[:version].reload.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: {
        arrangement_item_id: graph[:item].id,
        charging_supplier_id: graph[:supplier].id,
        label: "#{stage} persons #{SecureRandom.hex(3)}"
      }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor:, source:,
      source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { stage:, mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    attrs = {
      label: "Per person", economic_role: "supplier_charge", calculation_kind: "unit_rate",
      amount: "10.00", quantity_basis: "persons", pass_through: false
    }
    attrs[:participant_category_id] = participant_category.id if participant_category
    CreateSupplierCostComponent.new(
      agency: @agency, actor:, definition: definition.reload,
      definition_lock_version: definition.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: attrs
    ).call
    stamp_forecast_ready!(definition.reload)
    source.reload
  end

  def stamp_forecast_ready!(definition)
    definition.update!(
      status: "forecast_ready",
      forecast_ready_by: @actor,
      forecast_ready_at: Time.current,
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition),
      readiness_provenance: "M4B review fixture"
    )
  end

  def add_draft_item!(graph, prefix)
    arrangement = graph[:arrangement]
    version = graph[:version].reload
    departure = graph[:departure]
    item = arrangement.arrangement_items.create!(agency: @agency, departure: departure)
    version.arrangement_item_definitions.create!(
      agency: @agency,
      departure: departure,
      supplier_arrangement: arrangement,
      arrangement_item: item,
      name: "#{prefix} item",
      category: "lodging",
      capacity_management: "unmanaged",
      default_service_provider: graph[:supplier],
      position: version.arrangement_item_definitions.maximum(:position).to_i + 1
    )
    graph.merge(item: item, actor: graph[:actor] || @actor)
  end

  def alternative_binding_attrs(item_graph, group_key)
    {
      supplier_arrangement_id: item_graph[:arrangement].id,
      supplier_arrangement_version_id: item_graph[:version].id,
      arrangement_item_id: item_graph[:item].id,
      membership_kind: "alternative",
      alternative_group_key: group_key,
      alternative_group_label: "Dinner"
    }
  end
end
