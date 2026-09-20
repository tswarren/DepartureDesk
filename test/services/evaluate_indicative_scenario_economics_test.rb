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
end
