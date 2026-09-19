require "test_helper"

class EvaluateSupplierCostOccupancyPreviewTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    suffix = SecureRandom.hex(3)
    @departure = @agency.departures.create!(
      name: "M3C occupancy preview #{suffix}",
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
      display_name: "Preview Supplier #{suffix}"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure,
      contracting_supplier: @supplier,
      name: "Preview Arrangement #{suffix}"
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
        ServiceOccurrenceDefinition,
        ServiceOccurrence,
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

  test "Celebrity O1 per-cabin preview matches accepted Single Double Triple amounts" do
    item, resource, assumption, source, definition = celebrity_o1_graph

    result = EvaluateSupplierCostOccupancyPreview.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      source: source, definition: definition, assumption: assumption,
      item_definition: @version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id),
      resource_definition: @version.supplier_resource_definitions.find_by!(supplier_resource_id: resource.id)
    ).call

    assert_nil result.empty_reason
    by_label = result.profiles.index_by(&:label)

    single = by_label.fetch("Single occupancy")
    assert single.per_cabin.complete
    assert_equal 355_500, single.per_cabin.totals.forecast_supplier_cost_minor_units
    assert_equal 32_480, single.per_cabin.totals.expected_commission_minor_units
    assert_equal 323_020, single.per_cabin.totals.expected_net_cost_after_commission_minor_units
    assert_equal 162_400, component_amount(single, "Single occupancy supplement")
    assert_nil component_amount(single, "Additional fare")

    double = by_label.fetch("Double occupancy")
    assert_equal 386_200, double.per_cabin.totals.forecast_supplier_cost_minor_units
    assert_equal 32_480, double.per_cabin.totals.expected_commission_minor_units
    assert_equal 353_720, double.per_cabin.totals.expected_net_cost_after_commission_minor_units
    assert_nil component_amount(double, "Single occupancy supplement")
    assert_nil component_amount(double, "Additional fare")
    assert_equal 30_000, component_amount(double, "First/second discount")

    triple = by_label.fetch("Triple occupancy")
    assert_equal 468_750, triple.per_cabin.totals.forecast_supplier_cost_minor_units
    assert_equal 36_540, triple.per_cabin.totals.expected_commission_minor_units
    assert_equal 432_210, triple.per_cabin.totals.expected_net_cost_after_commission_minor_units
    assert_equal 40_600, component_amount(triple, "Additional fare")
    assert_nil component_amount(triple, "Single occupancy supplement")

    assert_empty result.rounding_differences
    assert_equal 1_210_450, result.combined_totals.forecast_supplier_cost_minor_units
  end

  test "raising a profile cabin count changes contribution not per-cabin preview" do
    _item, _resource, assumption, source, definition = celebrity_o1_graph
    double = assumption.supplier_cost_occupancy_profiles.find_by!(label: "Double occupancy")
    double.update!(resource_unit_count: 3)

    before_per_cabin = EvaluateSupplierCostOccupancyPreview.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      source: source, definition: definition, assumption: assumption.reload
    ).call.profiles.index_by(&:label).fetch("Double occupancy")

    assert_equal 386_200, before_per_cabin.per_cabin.totals.forecast_supplier_cost_minor_units
    assert_equal 1_158_600, before_per_cabin.contribution.totals.forecast_supplier_cost_minor_units

    combined = EvaluateSupplierCostForecast.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      probe_definition: definition
    ).call.arrangements.first.sources.first.totals
    assert_equal(
      before_per_cabin.contribution.totals.forecast_supplier_cost_minor_units +
        355_500 + 468_750,
      combined.forecast_supplier_cost_minor_units
    )
  end

  test "profile contribution sum can differ from combined forecast at rounding boundary" do
    item = create_item("Rounding cabin")
    assumption = create_assumption(item)
    category = SupplierCostParticipantCategory.create!(
      owner_attributes.merge(arrangement_item: item, label: "Guest", position: 1)
    )
    2.times do |index|
      profile = SupplierCostOccupancyProfile.create!(
        owner_attributes.merge(
          arrangement_item: item, supplier_cost_usage_assumption: assumption,
          label: "Cabin #{index + 1}", resource_unit_count: 1, position: index + 1
        )
      )
      SupplierCostOccupancyProfilePosition.create!(
        owner_attributes.merge(
          arrangement_item: item, supplier_cost_usage_assumption: assumption,
          supplier_cost_occupancy_profile: profile, participant_category: category,
          occupancy_position: 1
        )
      )
    end
    source = create_source(item: item, label: "Rounding terms")
    definition = create_definition(source)
    fare = create_component(
      definition, label: "Fare", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: 5,
      quantity_basis: "occupancy_positions", occupancy_position_from: 1, occupancy_position_to: 1,
      position: 1
    )
    commission = create_component(
      definition, label: "Commission", economic_role: "expected_commission",
      calculation_kind: "percentage", rate: BigDecimal("0.10"),
      percentage_treatment: "additive", position: 2
    )
    create_base(definition, commission, fare)

    result = EvaluateSupplierCostOccupancyPreview.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      source: source, definition: definition, assumption: assumption
    ).call

    assert result.rounding_differences.key?(:expected_commission_minor_units)
    assert_equal 1, result.rounding_differences[:expected_commission_minor_units]
    assert_match(/currency minor-unit boundary/, result.rounding_explanation)
  end

  test "missing exact-context profiles returns empty reason without amounts" do
    item = create_item("I1 Inside")
    occurrence = create_occurrence(item, "7-night Eastern Caribbean")
    item_assumption = create_assumption(item)
    category = SupplierCostParticipantCategory.create!(
      owner_attributes.merge(arrangement_item: item, label: "Guest", position: 1)
    )
    profile = SupplierCostOccupancyProfile.create!(
      owner_attributes.merge(
        arrangement_item: item, supplier_cost_usage_assumption: item_assumption,
        label: "Double", resource_unit_count: 1, position: 1
      )
    )
    SupplierCostOccupancyProfilePosition.create!(
      owner_attributes.merge(
        arrangement_item: item, supplier_cost_usage_assumption: item_assumption,
        supplier_cost_occupancy_profile: profile, participant_category: category,
        occupancy_position: 1
      )
    )
    source = create_source(item: item, occurrence: occurrence, label: "Sailing I1 terms")
    definition = create_definition(source)
    create_component(
      definition, label: "Fare", economic_role: "supplier_charge",
      calculation_kind: "unit_rate", amount_minor_units: 100_00,
      quantity_basis: "occupancy_positions", occupancy_position_from: 1, occupancy_position_to: 2,
      position: 1
    )

    result = EvaluateSupplierCostOccupancyPreview.new(
      agency: @agency, departure: @departure, arrangement: @arrangement,
      source: source, definition: definition, assumption: nil,
      item_definition: @version.arrangement_item_definitions.find_by!(arrangement_item_id: item.id),
      occurrence_definition: @version.service_occurrence_definitions.find_by!(service_occurrence_id: occurrence.id)
    ).call

    assert_empty result.profiles
    assert_match(/7-night Eastern Caribbean/, result.empty_reason)
    assert_match(/7-night Eastern Caribbean/, result.context_label)
    assert_no_match(/\bDouble\b/, result.empty_reason)
  end

  private

  def celebrity_o1_graph
    item = create_item("O1 cabin category")
    resource = create_resource(item, "O1 cabin")
    assumption = create_assumption(item, resource: resource)
    category = SupplierCostParticipantCategory.create!(
      owner_attributes.merge(arrangement_item: item, label: "Anonymous occupant", position: 1)
    )
    CELEBRITY_O1_ANONYMOUS_PROFILES.each_with_index do |fixture, index|
      profile = SupplierCostOccupancyProfile.create!(
        owner_attributes.merge(
          arrangement_item: item, supplier_cost_usage_assumption: assumption,
          label: fixture.fetch(:label), resource_unit_count: fixture.fetch(:resource_unit_count),
          position: index + 1
        )
      )
      fixture.fetch(:occupancy_positions).each do |occupancy_position|
        SupplierCostOccupancyProfilePosition.create!(
          owner_attributes.merge(
            arrangement_item: item, supplier_cost_usage_assumption: assumption,
            supplier_cost_occupancy_profile: profile, participant_category: category,
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
    [ item, resource, assumption, source, definition ]
  end

  def component_amount(profile_preview, label)
    component = profile_preview.per_cabin.components.find { |entry| entry.label == label }
    return nil unless component
    return nil if component.rounded_minor_units.zero?

    component.rounded_minor_units
  end

  def owner_attributes
    {
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version
    }
  end

  def create_item(name)
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      owner_attributes.merge(
        arrangement_item: item, name: name, category: "lodging",
        position: @version.arrangement_item_definitions.count + 1
      )
    )
    item
  end

  def create_assumption(item, resource: nil, occurrence: nil, **quantities)
    SupplierCostUsageAssumption.create!(
      owner_attributes.merge(
        { arrangement_item: item, supplier_resource: resource, service_occurrence: occurrence }.merge(quantities)
      )
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

  def create_occurrence(item, name)
    occurrence = item.service_occurrences.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      status: "planned"
    )
    @version.service_occurrence_definitions.create!(
      owner_attributes.merge(
        arrangement_item: item, service_occurrence: occurrence, name: name,
        starts_on: @departure.starts_on, ends_on: @departure.ends_on,
        time_zone: @departure.time_zone
      )
    )
    occurrence
  end

  def create_source(item: nil, resource: nil, occurrence: nil, label:)
    SupplierCostSource.create!(
      owner_attributes.merge(
        arrangement_item: item, supplier_resource: resource, service_occurrence: occurrence,
        charging_supplier: @supplier, label: label,
        position: @version.supplier_cost_sources.count + 1
      )
    )
  end

  def create_definition(source, stage: "estimate", mode: "calculated")
    SupplierCostDefinition.create!(
      owner_attributes.merge(
        supplier_cost_source: source, stage: stage, mode: mode,
        currency: "USD", rounding_mode: "half_up"
      )
    )
  end

  def create_component(definition, **attributes)
    SupplierCostComponent.create!(
      owner_attributes.merge({ supplier_cost_definition: definition, pass_through: false }.merge(attributes))
    )
  end

  def create_base(definition, component, base_component, position: 1)
    SupplierCostComponentBase.create!(
      owner_attributes.merge(
        supplier_cost_definition: definition, supplier_cost_component: component,
        base_component: base_component, direction: "add", position: position
      )
    )
  end
end
