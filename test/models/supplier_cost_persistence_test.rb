require "test_helper"

class SupplierCostPersistenceTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = @agency.departures.create!(
      name: "M3C persistence",
      starts_on: Date.new(2027, 1, 1),
      ends_on: Date.new(2027, 1, 8),
      time_zone: "America/New_York",
      operating_currency: "USD",
      responsible_office: offices(:harbor_main),
      responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization",
      supplier_reference: "SUP-830001",
      display_name: "M3C Supplier"
    )
    @arrangement = SupplierArrangement.create!(
      agency: @agency,
      departure: @departure,
      contracting_supplier: @supplier,
      name: "M3C Arrangement"
    )
    @version = @arrangement.versions.create!(
      agency: @agency,
      departure: @departure,
      version_number: 1
    )
  end

  test "cost tables use direct ownership UUIDv7 and timestamptz" do
    connection = ActiveRecord::Base.connection
    %w[
      supplier_cost_sources supplier_cost_definitions supplier_cost_components
      supplier_cost_component_bases supplier_cost_participant_categories
      supplier_cost_usage_assumptions supplier_cost_occupancy_profiles
      supplier_cost_occupancy_profile_positions
    ].each do |table|
      columns = connection.columns(table).index_by(&:name)
      assert_equal "uuidv7()", columns.fetch("id").default_function
      assert_equal "uuid", columns.fetch("agency_id").sql_type
      assert_equal "uuid", columns.fetch("departure_id").sql_type
      assert_includes columns.fetch("created_at").sql_type, "with time zone"
      assert_includes columns.fetch("updated_at").sql_type, "with time zone"
    end

    assert_equal "bigint", connection.columns(:supplier_cost_components).index_by(&:name).fetch("amount_minor_units").sql_type
    assert_equal 20, connection.columns(:supplier_cost_components).index_by(&:name).fetch("rate").precision
    assert_includes AuditEvent::ACTIONS, "supplier_arrangement.cost_definition_forecast_ready"
  end

  test "arrangement-wide sources and null-safe context uniqueness are constrained" do
    source = create_source
    assert source.arrangement_wide?

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostSource.transaction(requires_new: true) do
        SupplierCostSource.create!(source_attributes(position: 1, label: "Duplicate position"))
        ActiveRecord::Base.connection.execute("SET CONSTRAINTS supplier_cost_sources_position_unique IMMEDIATE")
      end
    end

    item = create_item
    assumption_attributes = item_owner_attributes(item).merge(
      expected_resource_units: nil,
      expected_persons: 0,
      expected_billable_nights: nil
    )
    SupplierCostUsageAssumption.create!(assumption_attributes)
    assert_raises(ActiveRecord::RecordNotUnique) do
      SupplierCostUsageAssumption.create!(assumption_attributes)
    end
  end

  test "exact-version composite keys reject cross-item context" do
    first_item = create_item(position: 1)
    second_item = create_item(position: 2)
    occurrence = first_item.service_occurrences.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement
    )
    @version.service_occurrence_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: first_item,
      service_occurrence: occurrence,
      name: "First occurrence",
      starts_on: @departure.starts_on,
      ends_on: @departure.starts_on,
      time_zone: @departure.time_zone
    )

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierCostSource.insert!(
        {
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          departure_id: @departure.id,
          supplier_arrangement_id: @arrangement.id,
          supplier_arrangement_version_id: @version.id,
          arrangement_item_id: second_item.id,
          service_occurrence_id: occurrence.id,
          supplier_resource_id: nil,
          charging_supplier_id: @supplier.id,
          label: "Invalid cross-item source",
          notes: nil,
          position: 1,
          lock_version: 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      )
    end
  end

  test "definition currency must equal departure currency in model and database" do
    source = create_source
    definition = SupplierCostDefinition.new(definition_attributes(source, currency: "EUR"))
    assert_not definition.valid?
    assert_includes definition.errors[:currency], "must equal the departure operating currency"

    assert_raises(ActiveRecord::InvalidForeignKey) do
      SupplierCostDefinition.insert!(
        {
          id: SecureRandom.uuid_v7,
          agency_id: @agency.id,
          departure_id: @departure.id,
          supplier_arrangement_id: @arrangement.id,
          supplier_arrangement_version_id: @version.id,
          supplier_cost_source_id: source.id,
          stage: "estimate",
          status: "working",
          mode: "calculated",
          currency: "EUR",
          rounding_mode: "half_up",
          lock_version: 0,
          created_at: Time.current,
          updated_at: Time.current
        }
      )
    end
  end

  test "component money inherits definition currency and kind shape is constrained" do
    definition = SupplierCostDefinition.create!(definition_attributes(create_source))
    component = SupplierCostComponent.create!(
      owner_attributes.merge(
        supplier_cost_definition: definition,
        label: "Fare",
        economic_role: "supplier_charge",
        calculation_kind: "fixed",
        amount_minor_units: 12_345,
        position: 1
      )
    )

    assert_equal "USD", component.amount.currency.iso_code
    assert_equal 12_345, component.amount.fractional

    assert_raises(ActiveRecord::StatementInvalid) do
      SupplierCostComponent.transaction(requires_new: true) do
        SupplierCostComponent.where(id: component.id).update_all(amount_minor_units: nil)
      end
    end
  end

  test "both departure currency commands freeze without rewriting component amounts" do
    definition = SupplierCostDefinition.create!(definition_attributes(create_source))
    component = SupplierCostComponent.create!(
      owner_attributes.merge(
        supplier_cost_definition: definition,
        label: "Frozen fare",
        economic_role: "supplier_charge",
        calculation_kind: "fixed",
        amount_minor_units: 50_00,
        position: 1
      )
    )

    update_error = assert_raises(AgencyCommand::Error) do
      UpdateDeparture.new(
        agency: @agency,
        actor: @admin,
        departure: @departure,
        attributes: departure_attributes(operating_currency: "EUR"),
        lock_version: @departure.lock_version
      ).call
    end
    assert_equal :invalid_state, update_error.code
    assert_equal "USD", @departure.reload.operating_currency
    assert_equal 50_00, component.reload.amount_minor_units

    Departure.where(id: @departure.id).update_all(
      status: "departed",
      departure_reference: "D-900001",
      first_activated_at: Time.current,
      departed_at: Time.current,
      updated_at: Time.current
    )
    @departure.reload
    correction_error = assert_raises(AgencyCommand::Error) do
      CorrectDepartureCurrency.new(
        agency: @agency,
        actor: @admin,
        departure: @departure,
        operating_currency: "EUR",
        reason: "Correction",
        lock_version: @departure.lock_version
      ).call
    end
    assert_equal :invalid_state, correction_error.code
    assert_equal "USD", @departure.reload.operating_currency
    assert_equal 50_00, component.reload.amount_minor_units
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

  def source_attributes(**overrides)
    owner_attributes.merge(
      charging_supplier: @supplier,
      label: "Arrangement fee",
      position: 1
    ).merge(overrides)
  end

  def create_source
    SupplierCostSource.create!(source_attributes)
  end

  def definition_attributes(source, **overrides)
    owner_attributes.merge(
      supplier_cost_source: source,
      stage: "estimate",
      currency: "USD"
    ).merge(overrides)
  end

  def create_item(position: 1)
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency,
      departure: @departure,
      supplier_arrangement: @arrangement,
      arrangement_item: item,
      name: "Item #{position}",
      category: "other",
      other_category_label: "Service",
      position: position
    )
    item
  end

  def item_owner_attributes(item)
    owner_attributes.merge(arrangement_item: item)
  end

  def departure_attributes(**overrides)
    {
      name: @departure.name,
      description: @departure.description,
      starts_on: @departure.starts_on,
      ends_on: @departure.ends_on,
      time_zone: @departure.time_zone,
      operating_currency: @departure.operating_currency
    }.merge(overrides)
  end
end
