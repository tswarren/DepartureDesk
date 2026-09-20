require "test_helper"

class M4BCelebrityVineyardProofTest < ActiveSupport::TestCase
  include M3fScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
  end

  test "Celebrity occupancy uses illustrative Client prices not M3F supplier fares" do
    cruise = m3f_activated_graph!(
      "M4B Celebrity",
      "Celebrity Beyond M4B",
      starts_on: Date.new(2027, 11, 6),
      ends_on: Date.new(2027, 11, 13)
    )
    m3f_create_celebrity_o1_cost!(cruise)
    offer = create_from_source(cruise, title: "O1 illustrative Client", resource: true)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: {
        components: [
          occupancy_component("First", "first", "210.00"),
          occupancy_component("Second", "second", "210.00"),
          occupancy_component("Additional", "additional", "55.00"),
          occupancy_component("Single", "single", "320.00")
        ]
      }
    ).call
    definition = offer.editable_draft_version.price_definition
    amounts = definition.service_offer_price_components.map(&:amount_minor_units)
    assert_not_includes amounts, 162_400
    assert_not_includes amounts, 40_600

    double = EvaluateClientPrice.new(
      definition: definition,
      scenario: { occupancy_positions: [ { key: "first" }, { key: "second" } ], resource_units: 1 }
    ).call
    assert double.complete
    assert_equal 42_000, double.amount_minor_units

    triple = EvaluateClientPrice.new(
      definition: definition,
      scenario: { occupancy_positions: [ { key: "first" }, { key: "second" }, { key: "additional" } ], resource_units: 1 }
    ).call
    assert_equal 47_500, triple.amount_minor_units

    single = EvaluateClientPrice.new(
      definition: definition,
      scenario: { occupancy_positions: [ { key: "single" } ], resource_units: 1 }
    ).call
    assert_equal 32_000, single.amount_minor_units
  end

  test "Hilton extra nights require entered billable nights" do
    graph = m3f_activated_graph!(
      "M4B Hilton",
      "Hilton extra night",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 8)
    )
    offer = create_from_source(graph, title: "Extra night", occurrence: true)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: offer, idempotency_key: SecureRandom.uuid,
      version_lock_version: offer.editable_draft_version.lock_version,
      attributes: { pattern: "per_night", amount: "175.00" }
    ).call
    missing = EvaluateClientPrice.new(
      definition: offer.editable_draft_version.price_definition,
      scenario: { persons: 1 }
    ).call
    assert_not missing.complete
    assert_equal :nights, missing.blockers.first[:field]

    priced = EvaluateClientPrice.new(
      definition: offer.editable_draft_version.price_definition,
      scenario: { nights: 1 }
    ).call
    assert priced.complete
    assert_equal 17_500, priced.amount_minor_units
    assert_not_includes offer.editable_draft_version.price_definition.service_offer_price_components.map(&:amount_minor_units), 0
  end

  test "Vineyard bundled formula and unpriced dinner remain complete" do
    package = EvaluateClientPrice::BundledPackage.new(
      base_price_minor_units: 55_000,
      currency: "USD",
      single_occupancy_supplement_rate: BigDecimal("1.0")
    )
    assert_equal 110_000, EvaluateClientPrice.new(bundled_package: package, scenario: { persons: 2 }).call.amount_minor_units
    assert_equal 110_000, EvaluateClientPrice.new(bundled_package: package, scenario: { persons: 1 }).call.amount_minor_units

    dinner = EvaluateClientPrice.new(bundled_completeness: true).call
    assert dinner.complete
    assert_equal :bundled_component, dinner.kind

    graph = m3f_activated_graph!(
      "M4B Vineyard proof",
      "Vineyard Tour M4B",
      starts_on: Date.new(2027, 6, 5),
      ends_on: Date.new(2027, 6, 7)
    )
    m3f_create_vineyard_costs!(graph)
    coach = create_from_source(graph, title: "Coach", occurrence: false, resource: false)
    CreateServiceOfferPriceDefinition.new(
      agency: @agency, actor: @actor, offer: coach, idempotency_key: SecureRandom.uuid,
      version_lock_version: coach.editable_draft_version.lock_version,
      attributes: { pattern: "per_person", amount: "75.00" }
    ).call
    economics = EvaluateIndicativeScenarioEconomics.new(
      agency: @agency, actor: @actor, offer: coach, scenario: { persons: 2 }
    ).call
    assert_equal :unknown, economics.status
    assert_match(/enrollment/i, economics.reason)
  end

  private

  def occupancy_component(label, key, amount)
    {
      label: label, client_role: "base_price", calculation_kind: "unit_rate",
      amount: amount, quantity_basis: "occupancy_positions", occupancy_position_key: key
    }
  end

  def create_from_source(graph, title:, occurrence: true, resource: false, pool: false)
    attrs = {
      supplier_arrangement_id: graph[:arrangement].id,
      supplier_arrangement_version_id: graph[:version].id,
      arrangement_item_id: graph[:item].id,
      client_title: title
    }
    attrs[:service_occurrence_id] = graph[:occurrence].id if occurrence
    attrs[:supplier_resource_id] = graph[:resource].id if resource
    attrs[:capacity_pool_id] = graph[:pool]&.id if pool
    CreateServiceOfferFromSource.new(
      agency: @agency, actor: @actor, departure: graph[:departure],
      idempotency_key: SecureRandom.uuid, attributes: attrs
    ).call.record
  end
end
