require "test_helper"

class EvaluateClientPriceTest < ActiveSupport::TestCase
  test "unit rate persons rounds each component then sums" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "base", label: "Per person", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 10_000, quantity_basis: "persons", position: 1
          }
        ]
      },
      scenario: { persons: 2 }
    ).call

    assert result.complete
    assert_equal 20_000, result.amount_minor_units
    assert_equal 2, result.lines.sole.quantity
    assert_equal 20_000, result.lines.sole.signed_revenue_effect_minor_units
  end

  test "included tax has revenue effect zero and cannot be a later percentage base" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "base", label: "Fare", client_role: "base_price", calculation_kind: "fixed",
            amount_minor_units: 11_000, quantity_basis: "service_instances", position: 1
          },
          {
            id: "tax", label: "Included tax", client_role: "tax_fee", calculation_kind: "percentage",
            rate: "0.1", percentage_treatment: "included", position: 2,
            bases: [ { base_component_id: "base", direction: "add" } ]
          }
        ]
      },
      scenario: { service_instances: 1 }
    ).call

    assert result.complete
    assert_equal 11_000, result.amount_minor_units
    tax = result.lines.find { |line| line.component_id == "tax" }
    assert tax.included
    assert_equal 0, tax.signed_revenue_effect_minor_units
    assert_equal 1_000, tax.formula[:rounded_minor_units]

    blocked = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "base", label: "Fare", client_role: "base_price", calculation_kind: "fixed",
            amount_minor_units: 11_000, quantity_basis: "service_instances", position: 1
          },
          {
            id: "tax", label: "Included tax", client_role: "tax_fee", calculation_kind: "percentage",
            rate: "0.1", percentage_treatment: "included", position: 2,
            bases: [ { base_component_id: "base", direction: "add" } ]
          },
          {
            id: "fee", label: "Later percent", client_role: "named_surcharge", calculation_kind: "percentage",
            rate: "0.05", percentage_treatment: "additive", position: 3,
            bases: [ { base_component_id: "tax", direction: "add" } ]
          }
        ]
      },
      scenario: { service_instances: 1 }
    ).call
    assert_not blocked.complete
    assert_match(/included-tax/i, blocked.blockers.first[:message])
  end

  test "generic versus specific base price overlap is incomplete" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "generic", label: "All", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 10_000, quantity_basis: "occupancy_positions", position: 1
          },
          {
            id: "first", label: "First", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 12_000, quantity_basis: "occupancy_positions",
            occupancy_position_key: "first", position: 2
          }
        ]
      },
      scenario: { occupancy_positions: [ { key: "first" } ] }
    ).call

    assert_not result.complete
    assert_match(/overlap/i, result.blockers.first[:message])
  end

  test "specific occupancy bases can coexist" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "first", label: "First", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 20_000, quantity_basis: "occupancy_positions",
            occupancy_position_key: "first", position: 1
          },
          {
            id: "additional", label: "Additional", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 5_000, quantity_basis: "occupancy_positions",
            occupancy_position_key: "additional", position: 2
          }
        ]
      },
      scenario: { occupancy_positions: [ { key: "first" }, { key: "additional" } ] }
    ).call

    assert result.complete
    assert_equal 25_000, result.amount_minor_units
  end

  test "line rounding uses half up and does not round the basket first" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "base", label: "Base", client_role: "base_price", calculation_kind: "fixed",
            amount_minor_units: 100, quantity_basis: "service_instances", position: 1
          },
          {
            id: "pct", label: "Third", client_role: "named_surcharge", calculation_kind: "percentage",
            rate: (BigDecimal("1") / 3).to_s("F"), percentage_treatment: "additive", position: 2,
            bases: [ { base_component_id: "base", direction: "add" } ]
          }
        ]
      },
      scenario: { service_instances: 1 }
    ).call

    assert result.complete
    assert_equal 133, result.amount_minor_units
  end

  test "nights are required only when a selected component needs them" do
    flat = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [ {
          id: "base", label: "Flat", client_role: "base_price", calculation_kind: "fixed",
          amount_minor_units: 9_000, quantity_basis: "service_instances", position: 1
        } ]
      },
      scenario: { service_instances: 1 }
    ).call
    assert flat.complete

    nights = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [ {
          id: "base", label: "Nightly", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 1_000, quantity_basis: "nights", position: 1
        } ]
      },
      scenario: { service_instances: 1 }
    ).call
    assert_not nights.complete
    assert_equal :nights, nights.blockers.first[:field]
  end

  test "vineyard bundled double is 2P and single adds rounded supplement" do
    package = EvaluateClientPrice::BundledPackage.new(
      base_price_minor_units: 40_000,
      currency: "USD",
      single_occupancy_supplement_rate: BigDecimal("1.0")
    )
    double = EvaluateClientPrice.new(bundled_package: package, scenario: { persons: 2 }).call
    assert double.complete
    assert_equal 80_000, double.amount_minor_units

    single = EvaluateClientPrice.new(bundled_package: package, scenario: { persons: 1 }).call
    assert single.complete
    assert_equal 80_000, single.amount_minor_units
    assert_equal 2, single.lines.size
    assert_equal "Single occupancy supplement", single.lines.last.label
  end

  test "unpriced bundled component is complete and service-sum adds named adjustments" do
    unpriced = EvaluateClientPrice.new(bundled_completeness: true).call
    assert unpriced.complete
    assert_equal 0, unpriced.amount_minor_units

    service = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [ {
          id: "base", label: "Dinner", client_role: "base_price", calculation_kind: "fixed",
          amount_minor_units: 7_500, quantity_basis: "service_instances", position: 1
        } ]
      },
      scenario: { service_instances: 1 }
    ).call
    summed = EvaluateClientPrice.new(
      service_sum: EvaluateClientPrice::ServiceSum.new(
        service_results: [ service ],
        adjustments: [ EvaluateClientPrice::NamedAdjustment.new(label: "Package surcharge", amount_minor_units: 250, direction: "add") ]
      )
    ).call
    assert summed.complete
    assert_equal 7_750, summed.amount_minor_units
  end

  test "discount subtracts and occupancy must fit resource count" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "base", label: "Fare", client_role: "base_price", calculation_kind: "fixed",
            amount_minor_units: 10_000, quantity_basis: "service_instances", position: 1
          },
          {
            id: "off", label: "Discount", client_role: "named_discount", calculation_kind: "fixed",
            amount_minor_units: 1_500, quantity_basis: "service_instances", position: 2
          }
        ]
      },
      scenario: { service_instances: 1 }
    ).call
    assert_equal 8_500, result.amount_minor_units

    overflow = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [ {
          id: "base", label: "First", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 1_000, quantity_basis: "occupancy_positions",
          occupancy_position_key: "first", position: 1
        } ]
      },
      scenario: { resource_units: 1, occupancy_positions: [ { key: "first" }, { key: "first" } ] }
    ).call
    assert_not overflow.complete
    assert_match(/one resource/i, overflow.blockers.first[:message])
  end

  test "mixed client rate categories charge matching persons not the full headcount" do
    definition = {
      currency: "USD",
      components: [
        {
          id: "adult", label: "Adult", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 10_000, quantity_basis: "persons",
          client_rate_category_key: "adult", position: 1
        },
        {
          id: "child", label: "Child", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 5_000, quantity_basis: "persons",
          client_rate_category_key: "child", position: 2
        }
      ]
    }
    result = EvaluateClientPrice.new(
      definition: definition,
      scenario: {
        persons: 2, resource_units: 1,
        occupancy_positions: [ { rate_category: "adult" }, { rate_category: "child" } ]
      }
    ).call

    assert result.complete
    assert_equal 15_000, result.amount_minor_units
    assert_equal 1, result.lines.find { |line| line.component_id == "adult" }.quantity
    assert_equal 1, result.lines.find { |line| line.component_id == "child" }.quantity
  end

  test "occupancy-keyed per-person rates count matching positions not leftover demand" do
    result = EvaluateClientPrice.new(
      definition: {
        currency: "USD",
        components: [
          {
            id: "first", label: "First", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 10_000, quantity_basis: "persons",
            occupancy_position_key: "first", position: 1
          },
          {
            id: "additional", label: "Additional", client_role: "base_price", calculation_kind: "unit_rate",
            amount_minor_units: 5_000, quantity_basis: "persons",
            occupancy_position_key: "additional", position: 2
          }
        ]
      },
      scenario: {
        persons: 2, resource_units: 1,
        occupancy_positions: [ { key: "first" }, { key: "additional" } ]
      }
    ).call

    assert result.complete
    assert_equal 15_000, result.amount_minor_units
  end

  test "one resource pattern times resource units prices two cabins as four occupancy fares" do
    definition = {
      currency: "USD",
      components: [
        {
          id: "first", label: "First", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 21_000, quantity_basis: "occupancy_positions",
          occupancy_position_key: "first", position: 1
        },
        {
          id: "second", label: "Second", client_role: "base_price", calculation_kind: "unit_rate",
          amount_minor_units: 21_000, quantity_basis: "occupancy_positions",
          occupancy_position_key: "second", position: 2
        }
      ]
    }

    two_cabins = EvaluateClientPrice.new(
      definition: definition,
      scenario: {
        persons: 4, resource_units: 2,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call
    assert two_cabins.complete
    assert_equal 84_000, two_cabins.amount_minor_units
    assert_equal 2, two_cabins.lines.find { |line| line.component_id == "first" }.quantity
    assert_equal 2, two_cabins.lines.find { |line| line.component_id == "second" }.quantity

    mismatch = EvaluateClientPrice.new(
      definition: definition,
      scenario: {
        persons: 2, resource_units: 2,
        occupancy_positions: [ { key: "first" }, { key: "second" } ]
      }
    ).call
    assert_not mismatch.complete
    assert_equal :persons, mismatch.blockers.first[:field]

    expanded = EvaluateClientPrice.new(
      definition: definition,
      scenario: {
        persons: 4, resource_units: 2,
        occupancy_positions: [ { key: "first" }, { key: "second" }, { key: "first" }, { key: "second" } ]
      }
    ).call
    assert_not expanded.complete
    assert_match(/one resource/i, expanded.blockers.first[:message])
  end
end
