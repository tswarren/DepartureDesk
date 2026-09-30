# frozen_string_literal: true

require "test_helper"

class CompileCruiseSupplierRatesWorkspaceTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @actor = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @actor,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: @provider.id
      },
      occurrence_attributes: {
        name: "Eastern Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    @arrangement = sailing.record.arrangement
    @version = @arrangement.versions.sole
  end

  test "a category without rates is not recorded" do
    add_cabin!

    row = compile.rows.sole

    assert_equal "—", row.stage_label
    assert_equal "Not recorded", row.status_label
    assert_equal "—", row.commission_label
    assert_not row.single.available?
    assert_not row.double.available?
    assert_not row.triple.available?
  end

  test "an unrelated supplier resource is not a cabin category" do
    cabin = add_cabin!
    item = cabin.record.resource.arrangement_item
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
      name: "Airport transfer",
      position: 2
    )

    workspace = compile

    assert_equal 1, workspace.category_count
    assert_equal [ cabin.record.resource.id ], workspace.rows.map(&:resource_id)
    assert workspace.attention_items.none? { |item| item.message.include?("Airport transfer") }
  end

  test "a ready estimate stays ready when activation still requires contracted rates" do
    cabin = add_cabin!
    create_rates!(cabin.record.resource)
    mark_ready!(cabin.record.resource)

    workspace = compile
    row = workspace.rows.sole
    item = workspace.attention_items.find { |attention| attention.code == :cruise_contracted_rates_missing }

    assert_equal "Estimate", row.stage_label
    assert_equal "Ready", row.status_label
    assert_equal "estimate", row.stage
    assert_equal "Record contracted Supplier rates for O1", item.message
    assert_equal cabin.record.resource.id, item.resource_id
    assert_equal "estimate", item.stage
    assert_not workspace.attention_items.any? { |attention| attention.code == :rate_review }
  end

  test "an unready estimate needs review and does not become a contracted stage" do
    cabin = add_cabin!
    create_rates!(cabin.record.resource)

    row = compile.rows.sole

    assert_equal "Estimate", row.stage_label
    assert_equal "Needs review", row.status_label
    assert_equal "Not provided yet", row.commission_label
  end

  test "recording contracted rates selects contracted and leaves the estimate unchanged" do
    cabin = add_cabin!
    create_rates!(cabin.record.resource)
    estimate = current_definition(cabin.record.resource)
    estimate_amounts = estimate.supplier_cost_components.order(:position, :id).pluck(:amount_minor_units, :label)

    RecordCruiseContractedRates.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: cabin.record.resource,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    workspace = compile
    row = workspace.rows.sole
    preferred = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: cabin.record.resource
    ).call
    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency,
      arrangement: @arrangement,
      resource: cabin.record.resource,
      version: @version.reload,
      stage: "contracted"
    ).call

    assert_equal "estimate", preferred.definition.stage
    assert_equal estimate.id, preferred.definition.id
    assert_equal "Contracted", row.stage_label
    assert_equal "Needs review", row.status_label
    assert_equal "contracted", row.stage
    assert_equal estimate_amounts, estimate.reload.supplier_cost_components.order(:position, :id).pluck(:amount_minor_units, :label)
    assert_equal preview.illustrations.map(&:key), row.illustrations.map(&:key)
    assert_equal preview.illustrations.map(&:gross_minor_units), row.illustrations.map(&:gross_minor_units)
    assert_equal preview.illustrations.map(&:label), row.illustrations.map(&:label)
  end

  test "a ready contracted definition is contracted and ready" do
    cabin = add_cabin!
    create_rates!(cabin.record.resource, stage: "contracted")
    mark_ready!(cabin.record.resource, stage: "contracted")

    row = compile.rows.sole

    assert_equal "Contracted", row.stage_label
    assert_equal "Ready", row.status_label
  end

  test "an unready contracted definition needs review" do
    cabin = add_cabin!
    create_rates!(cabin.record.resource, stage: "contracted")

    row = compile.rows.sole

    assert_equal "Contracted", row.stage_label
    assert_equal "Needs review", row.status_label
  end

  test "illustrative scenarios follow the preview and omit triple below maximum occupancy" do
    cabin = add_cabin!(name: "Deluxe Inside", code: "DI", occupancy: 2)
    create_rates!(cabin.record.resource)
    preview = CompileCruiseSupplierRatePreview.new(
      agency: @agency, arrangement: @arrangement, resource: cabin.record.resource, version: @version.reload
    ).call

    row = compile.rows.sole

    assert_equal preview.illustrations.map(&:key), row.illustrations.map(&:key)
    assert_equal preview.illustrations.map(&:label), row.illustrations.map(&:label)
    assert_equal preview.illustrations.map(&:gross_minor_units), row.illustrations.map(&:gross_minor_units)
    assert_not_includes row.illustrations.map(&:key), "triple"
    assert_includes row.illustrations.map(&:key), "double"
    double = preview.illustrations.find { |illustration| illustration.key == "double" }
    assert row.single.available?
    assert row.double.available?
    assert_not row.triple.available?
    assert_equal double.gross_minor_units, row.double.gross_minor_units
  end

  test "commission shows the recorded percentage or dollar term" do
    percentage_cabin = add_cabin!(name: "Prime Oceanview", code: "O1")
    create_rates!(percentage_cabin.record.resource, commission: {
      method: "percentage",
      percentage: "15",
      add_cells: %w[base_fare:first_second base_fare:additional base_fare:single_supplement],
      subtract_cells: %w[discount:first_second discount:additional]
    })
    dollar_cabin = add_cabin!(name: "Deluxe Inside", code: "DI")
    create_rates!(dollar_cabin.record.resource, commission: {
      method: "dollar",
      amount: "375.00",
      applies_per: "cabin"
    })
    mixed_cabin = add_cabin!(name: "Concierge", code: "C1")
    create_rates!(mixed_cabin.record.resource, commission: {
      method: "dollar",
      amounts: { "first_second" => "375.00", "additional" => "100.00" }
    })

    rows = compile.rows.index_by(&:code)

    assert_equal "15%", rows.fetch("O1").commission_label
    assert_equal "$375.00", rows.fetch("DI").commission_label
    assert_equal "Dollar amount", rows.fetch("C1").commission_label
  end

  test "an unrepresentable rate shape stays advanced" do
    cabin = add_cabin!
    create_rates!(cabin.record.resource)
    definition = current_definition(cabin.record.resource)
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

    row = compile.rows.sole

    assert_equal "Advanced", row.status_label
    assert row.advanced?
    assert_empty row.illustrations
    assert_equal "Advanced", row.commission_label
  end

  private

  def compile
    shape = DetectCruiseArrangementShape.new(agency: @agency, arrangement: @arrangement.reload).call
    CompileCruiseSupplierRatesWorkspace.new(agency: @agency, arrangement: @arrangement, shape: shape).call
  end

  def add_cabin!(name: "Prime Oceanview", code: "O1", occupancy: 3)
    CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource_attributes: { name: name, supplier_code: code, maximum_occupancy: occupancy },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 8 },
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def create_rates!(resource, stage: "estimate", commission: { method: "not_provided" })
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: resource,
      terms: {
        first_second_fare: "1624.00",
        additional_fare: "406.00",
        single_supplement: "1624.00",
        nccf: "320.00",
        first_second_discount: "150.00",
        additional_discount: "37.50",
        taxes_fees: "137.00"
      },
      commission: commission,
      stage: stage,
      version_lock_version: @version.reload.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
  end

  def mark_ready!(resource, stage: nil)
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: resource,
      expected_cabins: { double: 1 },
      version_lock_version: @version.reload.lock_version
    ).call
    definition = current_definition(resource, stage: stage)
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @actor,
      arrangement: @arrangement,
      resource: resource,
      definition_lock_version: definition.lock_version,
      readiness_provenance: "Signed terms",
      confirm_omissions: true,
      stage: stage
    ).call
  end

  def current_definition(resource, stage: nil)
    DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: resource, stage: stage
    ).call.definition
  end

end
