# frozen_string_literal: true

require "test_helper"

class CruiseSupplierRateScheduleTest < ActiveSupport::TestCase
  include M3CCostScenarioHelper

  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    @contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(**sailing_arguments).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
    cabin = create_cabin(@arrangement, @version)
    @resource = cabin.record.resource
    @version.reload
  end

  test "smith O1 gross totals leave commission pending" do
    create_smith_rates!

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call

    assert preview.compatible?
    assert_equal "not_provided", preview.commission_method
    by_key = preview.illustrations.index_by(&:key)
    assert_equal 355_500, by_key.fetch("single").gross_minor_units
    assert_equal 386_200, by_key.fetch("double").gross_minor_units
    assert_equal 468_750, by_key.fetch("triple").gross_minor_units
    assert_equal "pending", by_key.fetch("double").commission_state
    assert_equal "pending", by_key.fetch("double").net_state
    assert_nil by_key.fetch("double").net_minor_units
  end

  test "dollar commission per traveler and per cabin" do
    create_smith_rates!

    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: { method: "dollar", amount: "100.00", applies_per: "traveler" }
      )
    ).call

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    double = preview.illustrations.find { |row| row.key == "double" }
    assert_equal "shown", double.commission_state
    assert_equal 20_000, double.commission_minor_units
    assert_equal double.gross_minor_units - 20_000, double.net_minor_units

    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: { method: "dollar", amount: "50.00", applies_per: "cabin" }
      )
    ).call
    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    double = preview.illustrations.find { |row| row.key == "double" }
    assert_equal 5_000, double.commission_minor_units
  end

  test "percentage commission with fares and supplement and discount subtract" do
    create_smith_rates!

    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          add_cells: %w[base_fare:first_second base_fare:additional base_fare:single_supplement],
          subtract_cells: []
        }
      )
    ).call

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    single = preview.illustrations.find { |row| row.key == "single" }
    assert_equal "shown", single.commission_state
    assert single.commission_minor_units.positive?

    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          add_cells: %w[base_fare:first_second base_fare:additional],
          subtract_cells: %w[discount:first_second]
        }
      )
    ).call
    with_subtract = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.illustrations.find { |row| row.key == "double" }.commission_minor_units

    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          add_cells: %w[base_fare:first_second base_fare:additional],
          subtract_cells: []
        }
      )
    ).call
    without_subtract = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.illustrations.find { |row| row.key == "double" }.commission_minor_units

    assert with_subtract < without_subtract
  end

  test "commission method switch removes obsolete component shape" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: { method: "dollar", amount: "25.00", applies_per: "cabin" }
      )
    ).call
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          add_cells: %w[base_fare:first_second],
          subtract_cells: []
        }
      )
    ).call

    definition = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.definition
    commission = definition.supplier_cost_components.find_by!(economic_role: "expected_commission")
    assert_equal "percentage", commission.calculation_kind
    assert_equal 1, commission.supplier_cost_component_bases.count
  end

  test "matrix labels reopen as matrix not legacy" do
    create_smith_rates!
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    assert shape.compatible?
    assert shape.matrix?
    refute shape.legacy?
    assert_equal "Base Fare", shape.definition.supplier_cost_components.find_by!(
      quantity_basis: "occupancy_positions", occupancy_position_from: 1
    ).label
  end

  test "shared percentage stays one component after save" do
    create_smith_rates!
    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        commission: {
          method: "percentage",
          percentage: "10",
          add_cells: %w[base_fare:first_second base_fare:additional],
          subtract_cells: %w[discount:first_second]
        }
      )
    ).call
    definition = current_definition
    commissions = definition.supplier_cost_components.where(economic_role: "expected_commission")
    assert_equal 1, commissions.count
    assert_equal "percentage", commissions.first.calculation_kind
  end

  test "zero unit rate amount may become forecast ready with a positive sibling" do
    create_smith_rates!
    definition = current_definition
    zero = definition.supplier_cost_components.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Base Fare",
      economic_role: "supplier_charge",
      calculation_kind: "unit_rate",
      amount_minor_units: 0,
      quantity_basis: "resource_units",
      position: 50,
      pass_through: false
    )
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      expected_cabins: { double: 1 },
      version_lock_version: @version.reload.lock_version
    ).call
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: current_definition.lock_version,
      readiness_provenance: "Includes contractual zero",
      confirm_omissions: true
    ).call
    assert current_definition.reload.forecast_ready?
    assert_equal 0, zero.reload.amount_minor_units
  end

  test "legacy fixed form projects and converts with confirmation" do
    create_smith_rates!
    definition = current_definition
    # Simulate shipped 2A.2 labels still on disk.
    definition.supplier_cost_components.where(economic_role: %w[supplier_charge supplier_credit]).find_each do |component|
      legacy_label = CruiseSupplierRateSupport::LEGACY_LABEL_TO_CELL.find do |_label, pair|
        row_key, profile_key = pair
        component.label == CruiseSupplierRateSupport.static_row_label(row_key) &&
          CruiseSupplierRateSupport.profile_key_for_component(component).to_s == profile_key.to_s
      end&.first
      component.update_columns(label: legacy_label) if legacy_label
    end

    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    assert shape.legacy?
    refute shape.matrix?

    error = assert_raises(AgencyCommand::Error) do
      UpdateCruiseSupplierRateSchedule.new(**update_args.merge(convert_legacy: false)).call
    end
    assert_match(/confirm conversion/i, error.message)

    preserved_id = definition.supplier_cost_components.order(:position).first.id
    UpdateCruiseSupplierRateSchedule.new(**update_args.merge(convert_legacy: true)).call
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    assert shape.matrix?
    refute shape.legacy?
    assert_equal "Base Fare", shape.definition.supplier_cost_components.find(preserved_id).label
  end

  test "occupancy plan clears forecast readiness" do
    create_smith_rates!
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      expected_cabins: { double: 2 },
      version_lock_version: @version.reload.lock_version
    ).call

    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: current_definition.lock_version,
      readiness_provenance: "Smith O1 confirmed",
      confirm_omissions: true
    ).call
    assert current_definition.reload.forecast_ready?

    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      expected_cabins: { double: 4 },
      version_lock_version: @version.reload.lock_version,
      assumption_lock_version: @version.supplier_cost_usage_assumptions
        .find_by!(supplier_resource_id: @resource.id).lock_version
    ).call

    refute current_definition.reload.forecast_ready?
    assumption = @version.supplier_cost_usage_assumptions.find_by!(supplier_resource_id: @resource.id)
    profile = assumption.supplier_cost_occupancy_profiles.find_by!(label: "Double occupancy")
    assert_equal 4, profile.resource_unit_count
    assert_equal 2, profile.supplier_cost_occupancy_profile_positions.count
  end

  test "create is idempotent and rejects unsupported rewrite" do
    key = SecureRandom.uuid
    first = CreateCruiseSupplierRateSchedule.new(**create_args(idempotency_key: key)).call
    assert_equal :created, first.status
    second = CreateCruiseSupplierRateSchedule.new(**create_args(idempotency_key: key)).call
    assert_equal :replayed, second.status
    assert_equal first.record.source.id, second.record.source.id

    definition = first.record.definition
    definition.supplier_cost_components.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version,
      supplier_cost_definition: definition,
      label: "Tiered group fee",
      economic_role: "supplier_charge",
      calculation_kind: "fixed",
      amount_minor_units: 5_000,
      position: 99,
      pass_through: false
    )
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    refute shape.compatible?
  end

  test "maximum occupancy two does not offer triple illustration" do
    resource_definition = @version.supplier_resource_definitions.find_by!(supplier_resource_id: @resource.id)
    resource_definition.update!(maximum_occupancy: 2)
    create_smith_rates!

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    assert_equal %w[single double], preview.illustrations.map(&:key)
  end

  test "family rates support adult child custom row and profile specific commission" do
    adult_first = CruiseSupplierRateSupport.encode_profile_key(:first_second, category: "Adult")
    child_additional = CruiseSupplierRateSupport.encode_profile_key(:additional, category: "Child")
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      profiles: [
        { family: "first_second", category: "Adult" },
        { family: "additional", category: "Child" },
        { family: "every_traveler" },
        { family: "single_supplement" }
      ],
      custom_rows: [
        { key: "port_transfer", label: "Port transfer fee", economic_role: "supplier_charge" }
      ],
      cells: {
        "#{CruiseSupplierRateSupport.cell_key(:base_fare, adult_first)}" => "1000.00",
        "#{CruiseSupplierRateSupport.cell_key(:discount, adult_first)}" => "100.00",
        "#{CruiseSupplierRateSupport.cell_key(:base_fare, child_additional)}" => "400.00",
        "#{CruiseSupplierRateSupport.cell_key(:discount, child_additional)}" => "50.00",
        "#{CruiseSupplierRateSupport.cell_key(:nccf, :every_traveler)}" => "150.00",
        "#{CruiseSupplierRateSupport.cell_key(:taxes_fees, :every_traveler)}" => "75.00",
        "#{CruiseSupplierRateSupport.cell_key(:base_fare, :single_supplement)}" => "500.00",
        "#{CruiseSupplierRateSupport.cell_key(:discount, :single_supplement)}" => "40.00",
        "port_transfer:#{adult_first}" => "25.00"
      },
      commission: {
        method: "percentage",
        shared: false,
        add_cells: [
          CruiseSupplierRateSupport.cell_key(:base_fare, adult_first),
          CruiseSupplierRateSupport.cell_key(:base_fare, child_additional),
          CruiseSupplierRateSupport.cell_key(:base_fare, :single_supplement)
        ],
        subtract_cells: [
          CruiseSupplierRateSupport.cell_key(:discount, adult_first),
          CruiseSupplierRateSupport.cell_key(:discount, :single_supplement)
        ],
        rates: {
          adult_first => "10",
          child_additional => "5",
          "single_supplement" => "10"
        }
      },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    definition = current_definition
    assert definition.supplier_cost_components.any? { |c| c.label == "Port transfer fee" }
    commissions = definition.supplier_cost_components.where(economic_role: "expected_commission")
    assert_equal 3, commissions.count
    assert commissions.all? { |c| c.calculation_kind == "percentage" }

    child_discount = definition.supplier_cost_components.find_by!(
      label: "Discount",
      occupancy_position_from: 3
    )
    refute commissions.flat_map { |c| c.supplier_cost_component_bases.map(&:base_component_id) }
      .include?(child_discount.id)

    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    by_key = preview.illustrations.index_by(&:key)
    assert_equal %w[single_adult double_adult two_adults_child], by_key.keys
    assert by_key.fetch("single_adult").gross_minor_units.positive?
    assert_operator by_key.fetch("double_adult").gross_minor_units, :>, by_key.fetch("single_adult").gross_minor_units
    mixed_delta = by_key.fetch("two_adults_child").gross_minor_units - by_key.fetch("double_adult").gross_minor_units
    assert_operator mixed_delta, :>=, 40_000
  end

  test "category free and child overlap requires explicit resolution" do
    create_smith_rates!
    error = assert_raises(AgencyCommand::Error) do
      UpdateCruiseSupplierRateSchedule.new(
        **update_args.merge(
          profiles: [
            { family: "first_second" },
            { family: "first_second", category: "Child" }
          ],
          cells: {
            "base_fare:first_second" => "1624.00",
            "base_fare:#{CruiseSupplierRateSupport.encode_profile_key(:first_second, category: 'Child')}" => "800.00"
          }
        )
      ).call
    end
    assert_match(/overlap|resolution/i, error.message)

    UpdateCruiseSupplierRateSchedule.new(
      **update_args.merge(
        profiles: [
          { family: "first_second" },
          { family: "first_second", category: "Child" }
        ],
        cells: {
          "base_fare:first_second" => "1624.00",
          "base_fare:#{CruiseSupplierRateSupport.encode_profile_key(:first_second, category: 'Child')}" => "800.00"
        },
        overlap_resolution: "scope_existing_to_adult"
      )
    ).call
    shape = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    assert shape.compatible?
    labels = shape.definition.supplier_arrangement_version.supplier_cost_participant_categories
      .where(arrangement_item_id: shape.item.id).pluck(:label)
    assert_includes labels, "Adult"
    assert_includes labels, "Child"
  end

  test "changing terms stage after save raises a clear invalid error" do
    CreateCruiseSupplierRateSchedule.new(**create_args.merge(stage: "contracted")).call
    @version.reload

    error = assert_raises(AgencyCommand::Error) do
      UpdateCruiseSupplierRateSchedule.new(**update_args.merge(stage: "estimate")).call
    end
    assert_equal :invalid, error.code
    assert_match(/stage cannot be changed/i, error.message)
    assert_equal "contracted", current_definition.stage
  end

  test "bounded positions family compiles to occupancy positions" do
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      profiles: [
        { family: "bounded_positions", occupancy_position_from: 2, occupancy_position_to: 3, category: "Child" }
      ],
      cells: {
        "base_fare:bounded_2_3__Child" => "250.00"
      },
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    component = current_definition.supplier_cost_components.find_by!(label: "Base Fare")
    assert_equal "occupancy_positions", component.quantity_basis
    assert_equal 2, component.occupancy_position_from
    assert_equal 3, component.occupancy_position_to
    assert_equal "Child", component.participant_category.label
  end

  test "preview illustrations follow Staff-selected anonymous occupants" do
    adult_first = CruiseSupplierRateSupport.encode_profile_key(:first_second, category: "Adult")
    child_additional = CruiseSupplierRateSupport.encode_profile_key(:additional, category: "Child")
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      profiles: [
        { family: "first_second", category: "Adult" },
        { family: "additional", category: "Child" },
        { family: "every_traveler" }
      ],
      cells: {
        "#{CruiseSupplierRateSupport.cell_key(:base_fare, adult_first)}" => "1000.00",
        "#{CruiseSupplierRateSupport.cell_key(:base_fare, child_additional)}" => "400.00",
        "#{CruiseSupplierRateSupport.cell_key(:nccf, :every_traveler)}" => "100.00"
      },
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    default_preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call
    assert_includes default_preview.illustrations.map(&:key), "two_adults_child"

    custom = CompileCruiseSupplierRatePreview.new(
      agency: @agency,
      arrangement: @arrangement,
      resource: @resource,
      illustration_occupants: %w[Adult Child Adult]
    ).call
    assert_equal %w[occupants_1 occupants_2 occupants_3], custom.illustrations.map(&:key)
    assert_equal "Adult + Child + Adult", custom.illustrations.last.label
    refute_equal(
      default_preview.illustrations.index_by(&:key).fetch("two_adults_child").gross_minor_units,
      custom.illustrations.last.gross_minor_units
    )
  end

  private

  def sailing_arguments
    {
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: @contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    }
  end

  def create_cabin(arrangement, version)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: arrangement,
      resource_attributes: {
        name: "Prime Oceanview",
        supplier_code: "O1",
        maximum_occupancy: 3
      },
      pool_attributes: {
        inventory_mode: "block",
        proposed_opening_quantity: 8
      },
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def smith_terms
    {
      first_second_fare: "1624.00",
      additional_fare: "406.00",
      single_supplement: "1624.00",
      nccf: "320.00",
      first_second_discount: "150.00",
      additional_discount: "37.50",
      taxes_fees: "137.00"
    }
  end

  def create_args(idempotency_key: SecureRandom.uuid)
    {
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      terms: smith_terms,
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.reload.lock_version,
      idempotency_key: idempotency_key
    }
  end

  def create_smith_rates!
    CreateCruiseSupplierRateSchedule.new(**create_args).call
    @version.reload
  end

  def current_definition
    DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.definition
  end

  def update_args
    definition = current_definition
    {
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: @resource,
      terms: smith_terms,
      version_lock_version: @version.reload.lock_version,
      definition_lock_version: definition.lock_version
    }
  end
end
