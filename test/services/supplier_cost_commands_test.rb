require "test_helper"

class SupplierCostCommandsTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = @agency.departures.create!(
      name: "M3C commands", starts_on: Date.new(2027, 5, 1), ends_on: Date.new(2027, 5, 8),
      time_zone: "America/New_York", operating_currency: "USD",
      responsible_office: offices(:harbor_main), responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization", supplier_reference: "SUP-839991", display_name: "Cost Supplier"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure, contracting_supplier: @supplier, name: "Cost Arrangement"
    )
    @version = @arrangement.versions.create!(
      agency: @agency, departure: @departure, version_number: 1
    )
  end

  test "source create replays before stale version lock" do
    original_lock = @version.lock_version
    created = create_source("source-replay", original_lock)
    replay = create_source("source-replay", original_lock)

    assert_equal :created, created.status
    assert_equal :replayed, replay.status
    assert_equal created.record.id, replay.record.id
    assert_equal 1, AuditEvent.where(
      subject_type: "SupplierArrangement", subject_id: @arrangement.id,
      action: "supplier_arrangement.cost_source_created"
    ).count
  end

  test "readiness is explicit and a consequential component edit clears it" do
    source = create_source("source-ready", @version.lock_version).record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: "definition-ready",
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    component = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: "component-ready",
      attributes: {
        label: "Fare", economic_role: "supplier_charge", calculation_kind: "fixed",
        amount_minor_units: 10_000, pass_through: false
      }
    ).call.record

    ready = MarkCostDefinitionForecastReady.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      lock_version: definition.lock_version, readiness_provenance: "Supplier contract"
    ).call
    assert_equal :updated, ready.status
    assert definition.reload.forecast_ready?
    assert definition.readiness_fingerprint.present?

    UpdateSupplierCostComponent.new(
      agency: @agency, actor: @admin, component: component.reload,
      lock_version: component.lock_version, attributes: {
        label: "Updated fare", economic_role: component.economic_role,
        calculation_kind: component.calculation_kind, amount_minor_units: component.amount_minor_units,
        pass_through: component.pass_through
      }
    ).call
    assert definition.reload.working?
    assert_nil definition.readiness_fingerprint
  end

  test "fixed component create rejects nonblank incompatible form fields" do
    source = create_source("source-fixed-shape", @version.lock_version).record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: "definition-fixed-shape",
      attributes: { stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierCostComponent.new(
        agency: @agency, actor: @admin, definition: definition,
        definition_lock_version: definition.lock_version, idempotency_key: "component-fixed-shape",
        attributes: {
          label: "Base Fare", economic_role: "supplier_charge", calculation_kind: "fixed",
          amount_minor_units: 162_900, rate: "1.0", quantity_basis: "persons",
          percentage_treatment: "additive", pass_through: false
        }
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/not valid for this calculation/i, error.message)

    result = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: "component-fixed-ok",
      attributes: {
        label: "Base Fare", economic_role: "supplier_charge", calculation_kind: "fixed",
        amount: "1629.00", rate: "", quantity_basis: "", percentage_treatment: "", pass_through: false
      }
    ).call
    assert_equal :created, result.status
    assert_equal 162_900, result.record.amount_minor_units
  end

  test "unit rate component create requires quantity basis" do
    source = create_source("source-unit-rate-shape", @version.lock_version).record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: "definition-unit-rate-shape",
      attributes: { stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record

    error = assert_raises(AgencyCommand::Error) do
      CreateSupplierCostComponent.new(
        agency: @agency, actor: @admin, definition: definition,
        definition_lock_version: definition.lock_version, idempotency_key: "component-unit-rate-shape",
        attributes: {
          label: "Cabin fare", economic_role: "supplier_charge", calculation_kind: "unit_rate",
          amount_minor_units: 162_900, pass_through: false
        }
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/Quantity basis/i, error.message)
  end

  test "percentage components can reorder when dependent stays after bases" do
    source = create_source("source-reorder-bases", @version.lock_version).record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: "definition-reorder-bases",
      attributes: { stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    fare = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: "fare-reorder",
      attributes: {
        label: "Fare", economic_role: "supplier_charge", calculation_kind: "fixed",
        amount_minor_units: 10_000, pass_through: false
      }
    ).call.record
    discount = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      definition_lock_version: definition.lock_version, idempotency_key: "discount-reorder",
      attributes: {
        label: "Discount", economic_role: "supplier_credit", calculation_kind: "fixed",
        amount_minor_units: 1_000, pass_through: false
      }
    ).call.record
    commission = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      definition_lock_version: definition.lock_version, idempotency_key: "commission-reorder",
      base_links: [
        { base_component_id: fare.id, direction: "add" },
        { base_component_id: discount.id, direction: "subtract" }
      ],
      attributes: {
        label: "Commission", economic_role: "expected_commission", calculation_kind: "percentage",
        rate: "0.15", percentage_treatment: "additive", pass_through: false
      }
    ).call.record

    result = ReorderSupplierCostComponents.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      definition_lock_version: definition.lock_version,
      supplier_cost_component_ids: [ discount.id, fare.id, commission.id ]
    ).call

    assert_equal :updated, result.status
    assert_equal [ discount.id, fare.id, commission.id ],
      definition.supplier_cost_components.order(:position).pluck(:id)
  end

  test "readiness rejects quantity minimum with incompatible unit-rate base" do
    item = create_item
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      idempotency_key: "assumption-qty-min", attributes: { expected_persons: 3, expected_resource_units: 1 }
    ).call
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: "source-qty-min",
      attributes: { arrangement_item_id: item.id, charging_supplier_id: @supplier.id, label: "Excursion" }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: "definition-qty-min",
      attributes: { stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    rate = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: "rate-qty-min",
      attributes: {
        label: "Per person", economic_role: "supplier_charge", calculation_kind: "unit_rate",
        amount_minor_units: 5_000, quantity_basis: "persons", pass_through: false
      }
    ).call.record
    shortfall = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition.reload,
      definition_lock_version: definition.lock_version, idempotency_key: "shortfall-qty-min",
      base_links: [ { base_component_id: rate.id, direction: "add" } ],
      attributes: {
        label: "Minimum five", economic_role: "supplier_charge",
        calculation_kind: "minimum_quantity_shortfall", minimum_quantity: 5,
        quantity_basis: "persons", pass_through: false
      }
    ).call.record
    shortfall.update_columns(quantity_basis: "resource_units")

    error = assert_raises(AgencyCommand::Error) do
      MarkCostDefinitionForecastReady.new(
        agency: @agency, actor: @admin, definition: definition.reload,
        lock_version: definition.lock_version
      ).call
    end
    assert_equal :invalid, error.code
    assert_match(/compatible earlier unit-rate/i, error.message)
  end

  test "item source create treats blank occurrence and resource ids as entire item" do
    item = create_item

    result = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.lock_version, idempotency_key: "item-source-blank-scope",
      attributes: {
        arrangement_item_id: item.id, charging_supplier_id: @supplier.id, label: "01 Base",
        service_occurrence_id: "", supplier_resource_id: ""
      }
    ).call

    assert_equal :created, result.status
    source = result.record
    assert_equal item.id, source.arrangement_item_id
    assert_nil source.service_occurrence_id
    assert_nil source.supplier_resource_id
  end

  test "M3A removal reports cost dependencies" do
    item = create_item
    CreateSupplierCostUsageAssumption.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      idempotency_key: "assumption-dependency", attributes: { expected_persons: 2 }
    ).call

    error = assert_raises(AgencyCommand::Error) do
      RemoveArrangementItem.new(
        agency: @agency, actor: @admin, item: item,
        version_lock_version: @version.reload.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code
  end

  test "charging supplier blocks ordinary inactivation and forced inactivation permits source removal only" do
    source = create_source("source-inactivation", @version.lock_version).record

    error = assert_raises(AgencyCommand::Error) do
      ChangeSupplierStatus.new(
        agency: @agency, actor: @admin, supplier: @supplier, status: "inactive",
        lock_version: @supplier.lock_version
      ).call
    end
    assert_equal :dependency_exists, error.code

    ChangeSupplierStatus.new(
      agency: @agency, actor: @admin, supplier: @supplier, status: "inactive",
      lock_version: @supplier.reload.lock_version, force: true, force_reason: "Supplier closed"
    ).call
    update_error = assert_raises(AgencyCommand::Error) do
      UpdateSupplierCostSource.new(
        agency: @agency, actor: @admin, source: source, lock_version: source.lock_version,
        attributes: { label: "Cannot edit" }
      ).call
    end
    assert_equal :invalid_state, update_error.code

    removed = RemoveSupplierCostSource.new(
      agency: @agency, actor: @admin, source: source,
      version_lock_version: @version.reload.lock_version
    ).call
    assert_equal :updated, removed.status
  end

  private

  def create_source(key, version_lock)
    CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: version_lock, idempotency_key: key,
      attributes: { charging_supplier_id: @supplier.id, label: "Arrangement fee" }
    ).call
  end

  def create_item
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Cabin", category: "lodging", position: 1
    )
    item
  end
end
