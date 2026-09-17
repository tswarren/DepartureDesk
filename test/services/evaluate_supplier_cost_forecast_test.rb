require "test_helper"

class EvaluateSupplierCostForecastTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    suffix = SecureRandom.hex(3)
    @departure = @agency.departures.create!(
      name: "M3C forecast #{suffix}",
      starts_on: Date.new(2027, 8, 1),
      ends_on: Date.new(2027, 8, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_office: offices(:harbor_main),
      responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-#{SecureRandom.random_number(1_000_000).to_s.rjust(6, "0")}",
      display_name: "Forecast Supplier #{suffix}"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: "Forecast Arrangement #{suffix}"
    )
    @version = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
  end

  teardown do
    if @departure&.persisted?
      [
        SupplierCostOccupancyProfilePosition,
        SupplierCostOccupancyProfile,
        SupplierCostUsageAssumption,
        SupplierCostComponentBase,
        SupplierCostComponent,
        SupplierCostDefinition,
        SupplierCostSource,
        SupplierCostParticipantCategory,
        ArrangementItemDefinition,
        SupplierResourceDefinition,
        SupplierResource,
        ArrangementItem,
        SupplierArrangementVersion,
        SupplierArrangement
      ].each { |model| model.where(departure_id: @departure.id).delete_all }
      @departure.delete
      @supplier.delete if @supplier&.persisted?
    end
  end

  test "excursion quantity minimum explains three planned people against five billed" do
    item = create_item("Excursion")
    assumption = create_assumption(item, expected_persons: 3)
    source = create_source(item: item, label: "Excursion admission")
    definition = create_definition(source)
    rate = create_component(
      definition,
      label: "Admission per person",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      amount_minor_units: 5_000,
      quantity_basis: "persons",
      position: 1
    )
    shortfall = create_component(
      definition,
      label: "Five-person minimum",
      economic_role: "supplier_charge",
      calculation_kind: "minimum_quantity_shortfall",
      minimum_quantity: 5,
      quantity_basis: "persons",
      position: 2
    )
    create_base(definition, shortfall, rate)
    mark_ready(definition)
    audit_count = AuditEvent.count
    timestamps = [ source.updated_at, definition.reload.updated_at, assumption.updated_at ]

    result, sql = capture_sql do
      EvaluateSupplierCostForecast.new(
        agency: @agency, departure: @departure, arrangement: @arrangement
      ).call
    end

    source_result = result.arrangements.first.sources.first
    assert result.complete
    assert source_result.complete
    assert_equal 15_000, source_result.components.first.rounded_minor_units
    explanation = source_result.components.second.formula
    assert_equal 3, explanation[:planned_quantity]
    assert_equal 5, explanation[:minimum_billed_quantity]
    assert_equal 2, explanation[:missing_billed_quantity]
    assert_equal 5_000, explanation[:unit_rate_minor_units]
    assert_equal 10_000, explanation[:monetary_shortfall_minor_units]
    assert_equal 25_000, source_result.totals.forecast_supplier_cost_minor_units
    assert_equal 25_000, result.totals.expected_net_cost_after_commission_minor_units
    assert_equal audit_count, AuditEvent.count
    assert_equal timestamps, [ source.reload.updated_at, definition.reload.updated_at, assumption.reload.updated_at ]
    assert sql.any? { |statement| statement.match?(/REPEATABLE READ/i) }
    assert sql.any? { |statement| statement.match?(/SET TRANSACTION READ ONLY/i) }
  end

  test "Celebrity O1 fixture reproduces accepted amounts and roles with anonymous occupancy" do
    item = create_item("O1 cabin category")
    resource = create_resource(item, "O1 cabin")
    assumption = create_assumption(item, resource: resource)
    category = SupplierCostParticipantCategory.create!(
      owner_attributes.merge(arrangement_item: item, label: "Anonymous occupant", position: 1)
    )
    CELEBRITY_O1_ANONYMOUS_PROFILES.each_with_index do |fixture, index|
      profile = SupplierCostOccupancyProfile.create!(
        owner_attributes.merge(
          arrangement_item: item,
          supplier_cost_usage_assumption: assumption,
          label: fixture.fetch(:label),
          resource_unit_count: fixture.fetch(:resource_unit_count),
          position: index + 1
        )
      )
      fixture.fetch(:occupancy_positions).each do |occupancy_position|
        SupplierCostOccupancyProfilePosition.create!(
          owner_attributes.merge(
            arrangement_item: item,
            supplier_cost_usage_assumption: assumption,
            supplier_cost_occupancy_profile: profile,
            participant_category: category,
            occupancy_position: occupancy_position
          )
        )
      end
    end

    source = create_source(item: item, resource: resource, label: "O1 cabin terms")
    definition = create_definition(source, stage: "contracted")
    first_second_fare = create_component(
      definition, label: "First/second fare", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:first_second_fare),
      quantity_basis: "occupancy_positions", occupancy_position_from: 1, occupancy_position_to: 2, position: 1
    )
    additional_fare = create_component(
      definition, label: "Additional fare", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:additional_fare),
      quantity_basis: "occupancy_positions", occupancy_position_from: 3, position: 2
    )
    create_component(
      definition, label: "NCCF", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:nccf),
      quantity_basis: "persons", position: 3
    )
    create_component(
      definition, label: "First/second discount", economic_role: "supplier_credit",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:first_second_discount),
      quantity_basis: "occupancy_positions", occupancy_position_from: 1, occupancy_position_to: 2, position: 4
    )
    create_component(
      definition, label: "Additional discount", economic_role: "supplier_credit",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:additional_discount),
      quantity_basis: "occupancy_positions", occupancy_position_from: 3, position: 5
    )
    create_component(
      definition, label: "Taxes/fees/port charges", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:taxes_fees_port_charges),
      quantity_basis: "persons", position: 6
    )
    single_supplement = create_component(
      definition, label: "Single occupancy supplement", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: CELEBRITY_O1_AMOUNTS.fetch(:first_second_fare),
      quantity_basis: "single_occupancy_units", position: 7
    )
    commission = create_component(
      definition, label: "Expected commission", economic_role: "expected_commission",
      calculation_kind: "percentage", rate: BigDecimal("0.10"),
      percentage_treatment: "additive", position: 8
    )
    [ first_second_fare, additional_fare, single_supplement ].each_with_index do |base, index|
      create_base(definition, commission, base, position: index + 1)
    end
    mark_ready(definition, provenance: "M3C accepted Celebrity O1 fixture")

    source_result = evaluate.arrangements.first.sources.first
    components = source_result.components.index_by(&:label)

    assert source_result.complete
    assert_equal "contracted", source_result.selected_stage
    assert_match(/supersede/, source_result.selection_reason)
    assert_equal 5, components.fetch("First/second fare").quantity
    assert_equal 1, components.fetch("Additional fare").quantity
    assert_equal 6, components.fetch("NCCF").quantity
    assert_equal 1, components.fetch("Single occupancy supplement").quantity
    accepted_component_rates = {
      "First/second fare" => 162_400,
      "Additional fare" => 40_600,
      "NCCF" => 32_000,
      "First/second discount" => -15_000,
      "Additional discount" => -3_750,
      "Taxes/fees/port charges" => 13_700
    }
    assert_equal accepted_component_rates, accepted_component_rates.keys.to_h { |label|
      component = components.fetch(label)
      amount = component.formula.fetch(:unit_rate_minor_units)
      [ label, component.economic_role == "supplier_credit" ? -amount : amount ]
    }
    assert_equal(
      {
        "First/second fare" => 812_000,
        "Additional fare" => 40_600,
        "NCCF" => 192_000,
        "First/second discount" => 75_000,
        "Additional discount" => 3_750,
        "Taxes/fees/port charges" => 82_200,
        "Single occupancy supplement" => 162_400,
        "Expected commission" => 101_500
      },
      components.transform_values(&:rounded_minor_units)
    )
    assert_equal(
      %w[supplier_charge supplier_credit expected_commission],
      components.values.map(&:economic_role).uniq
    )
    assert_equal 1_289_200, source_result.totals.supplier_charges_minor_units
    assert_equal 78_750, source_result.totals.supplier_credits_minor_units
    assert_equal 1_210_450, source_result.totals.forecast_supplier_cost_minor_units
    assert_equal 101_500, source_result.totals.expected_commission_minor_units
    assert_equal 1_108_950, source_result.totals.expected_net_cost_after_commission_minor_units
    assert_not Object.const_defined?(:Traveler)
  end

  test "departure-level forecast excludes abandoned arrangements while arrangement probe retains them" do
    item = create_item("Abandoned costed service")
    source = create_source(item: item, label: "Abandoned terms")
    definition = create_definition(source, stage: "contracted")
    create_component(
      definition, label: "Fee", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: 25_000, position: 1
    )
    mark_ready(definition, provenance: "Abandoned arrangement retention")
    @arrangement.update!(status: "abandoned", abandoned_at: Time.current)

    departure_result = EvaluateSupplierCostForecast.new(agency: @agency, departure: @departure).call
    assert_empty departure_result.arrangements

    retained = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement
    ).call
    assert_equal 1, retained.arrangements.size
    assert_equal 25_000, retained.arrangements.first.totals.forecast_supplier_cost_minor_units
  end

  test "evaluates monetary roles percentages and minima with component half-up rounding" do
    item = create_item("Costed service")
    source = create_source(item: item, label: "Layered terms")
    definition = create_definition(source)
    fare = create_component(
      definition, label: "Fare", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: 10_000, position: 1
    )
    tax = create_component(
      definition, label: "Tax", economic_role: "supplier_charge",
      calculation_kind: "percentage", rate: BigDecimal("0.07505"),
      percentage_treatment: "additive", position: 2
    )
    create_base(definition, tax, fare)
    included = create_component(
      definition, label: "Included tax allocation", economic_role: "informational_allocation",
      calculation_kind: "percentage", rate: BigDecimal("0.10"),
      percentage_treatment: "included", position: 3
    )
    create_base(definition, included, fare)
    minimum = create_component(
      definition, label: "Minimum amount", economic_role: "supplier_charge",
      calculation_kind: "minimum_amount_shortfall", minimum_minor_units: 12_000, position: 4
    )
    create_base(definition, minimum, fare, position: 1)
    create_base(definition, minimum, tax, position: 2)
    create_component(
      definition, label: "Supplier discount", economic_role: "supplier_credit",
      calculation_kind: "fixed", amount_minor_units: 500, position: 5
    )
    commission = create_component(
      definition, label: "Expected commission", economic_role: "expected_commission",
      calculation_kind: "percentage", rate: BigDecimal("0.05"),
      percentage_treatment: "additive", position: 6
    )
    create_base(definition, commission, fare)
    mark_ready(definition)

    source_result = evaluate.arrangements.first.sources.first

    assert_equal [ 10_000, 751, 909, 1_249, 500, 500 ],
      source_result.components.map(&:rounded_minor_units)
    assert_equal 12_000, source_result.totals.supplier_charges_minor_units
    assert_equal 500, source_result.totals.supplier_credits_minor_units
    assert_equal 11_500, source_result.totals.forecast_supplier_cost_minor_units
    assert_equal 500, source_result.totals.expected_commission_minor_units
    assert_equal 11_000, source_result.totals.expected_net_cost_after_commission_minor_units
  end

  test "invalid contracted fingerprint fails closed without estimate fallback" do
    item = create_item("Staged service")
    source = create_source(item: item, label: "Staged terms")
    estimate = create_definition(source, stage: "estimate")
    create_component(
      estimate, label: "Estimate", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: 8_000, position: 1
    )
    mark_ready(estimate)
    contracted = create_definition(source, stage: "contracted")
    contracted_component = create_component(
      contracted, label: "Contracted", economic_role: "supplier_charge",
      calculation_kind: "fixed", amount_minor_units: 7_000, position: 1
    )
    mark_ready(contracted, provenance: "Signed Supplier agreement")
    SupplierCostComponent.where(id: contracted_component.id).update_all(label: "Changed outside command")

    result = evaluate
    source_result = result.arrangements.first.sources.first

    assert_not result.complete
    assert_equal "contracted", source_result.selected_stage
    assert_not source_result.complete
    assert_includes source_result.warnings.map { |entry| entry[:code] }, :invalid_readiness_fingerprint
    assert_equal "Known forecast subtotal", result.subtotal_label
    assert_equal 0, result.totals.forecast_supplier_cost_minor_units
  end

  test "arrangement-wide source does not satisfy Item coverage" do
    item = create_item("Uncovered service")
    source = create_source(label: "Arrangement administration")
    definition = create_definition(source, mode: "zero_cost", zero_cost_reason: "Complimentary")
    mark_ready(definition)

    result = evaluate
    arrangement = result.arrangements.first

    assert_not result.complete
    assert_equal [ item.id ], arrangement.uncovered_item_ids
    assert_empty arrangement.incomplete_source_ids
    assert_equal "Known forecast subtotal", arrangement.subtotal_label
    assert arrangement.sources.first.complete
  end

  test "explicit Item zero cost is complete while an Item with no source remains incomplete" do
    complimentary_item = create_item("Complimentary service")
    missing_item = create_item("Unspecified service")
    source = create_source(item: complimentary_item, label: "Supplier-collected service")
    definition = create_definition(
      source, mode: "zero_cost", zero_cost_reason: "Collected directly by Supplier"
    )
    mark_ready(definition)

    result = evaluate
    source_result = result.arrangements.first.sources.sole

    assert source_result.complete
    assert_equal "Collected directly by Supplier", source_result.zero_cost_reason
    assert_empty source_result.components
    assert_equal 0, source_result.totals.forecast_supplier_cost_minor_units
    assert_not result.complete
    assert_equal [ missing_item.id ], result.uncovered_item_ids
    assert_not_includes result.uncovered_item_ids, complimentary_item.id
    assert_empty result.incomplete_source_ids
  end

  private

  def owner_attributes
    {
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version
    }
  end

  def create_item(name)
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      owner_attributes.merge(
        arrangement_item: item,
        name: name,
        category: "activity_attraction",
        position: @version.arrangement_item_definitions.count + 1
      )
    )
    item
  end

  def create_assumption(item, resource: nil, **quantities)
    SupplierCostUsageAssumption.create!(
      owner_attributes.merge({ arrangement_item: item, supplier_resource: resource }.merge(quantities))
    )
  end

  def create_resource(item, name)
    resource = item.supplier_resources.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement
    )
    @version.supplier_resource_definitions.create!(
      owner_attributes.merge(
        arrangement_item: item, supplier_resource: resource, name: name, position: 1
      )
    )
    resource
  end

  def create_source(item: nil, resource: nil, label:)
    SupplierCostSource.create!(
      owner_attributes.merge(
        arrangement_item: item,
        supplier_resource: resource,
        charging_supplier: @supplier,
        label: label,
        position: @version.supplier_cost_sources.count + 1
      )
    )
  end

  def create_definition(source, stage: "estimate", mode: "calculated", zero_cost_reason: nil)
    SupplierCostDefinition.create!(
      owner_attributes.merge(
        supplier_cost_source: source,
        stage: stage,
        mode: mode,
        zero_cost_reason: zero_cost_reason,
        currency: "USD",
        rounding_mode: "half_up"
      )
    )
  end

  def create_component(definition, **attributes)
    SupplierCostComponent.create!(
      owner_attributes.merge(
        {
          supplier_cost_definition: definition,
          pass_through: false
        }.merge(attributes)
      )
    )
  end

  def create_base(definition, component, base_component, position: 1)
    SupplierCostComponentBase.create!(
      owner_attributes.merge(
        supplier_cost_definition: definition,
        supplier_cost_component: component,
        base_component: base_component,
        direction: "add",
        position: position
      )
    )
  end

  def mark_ready(definition, provenance: nil)
    definition.reload
    definition.update!(
      status: "forecast_ready",
      forecast_ready_by: @admin,
      forecast_ready_at: Time.current,
      readiness_provenance: provenance,
      readiness_fingerprint: SupplierCostDefinitionFingerprint.call(definition)
    )
  end

  def evaluate
    EvaluateSupplierCostForecast.new(
      agency: @agency,
      departure: @departure,
      arrangement: @arrangement
    ).call
  end

  def capture_sql
    statements = []
    subscriber = lambda do |_name, _started, _finished, _unique_id, payload|
      statements << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    result = nil
    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { result = yield }
    [ result, statements ]
  end
end
