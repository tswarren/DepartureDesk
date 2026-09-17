require "test_helper"

class M3CSupplierCostsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @viewer = agency_users(:harbor_viewer)
    @departure = @agency.departures.create!(
      name: "M3C request", starts_on: Date.new(2027, 4, 1), ends_on: Date.new(2027, 4, 8),
      time_zone: "America/New_York", operating_currency: "USD",
      responsible_office: offices(:harbor_main), responsible_agency_user: @admin
    )
    @supplier = @agency.suppliers.create!(
      kind: "organization", supplier_reference: "SUP-839992", display_name: "Request Cost Supplier"
    )
    @arrangement = @agency.supplier_arrangements.create!(
      departure: @departure, contracting_supplier: @supplier, name: "Cost request arrangement"
    )
    @version = @arrangement.versions.create!(
      agency: @agency, departure: @departure, version_number: 1
    )
  end

  test "administrator creates an arrangement-wide source and marks a zero stage ready" do
    sign_in_as @admin

    assert_difference -> { @version.supplier_cost_sources.count }, 1 do
      post departure_arrangement_costs_path(@departure, @arrangement), params: {
        idempotency_key: SecureRandom.uuid, version_lock_version: @version.lock_version,
        supplier_cost_source: { label: "Group fee", charging_supplier_id: @supplier.id }
      }
    end
    source = @version.supplier_cost_sources.find_by!(label: "Group fee")

    post departure_arrangement_cost_definitions_path(@departure, @arrangement, source), params: {
      idempotency_key: SecureRandom.uuid, source_lock_version: source.lock_version,
      supplier_cost_definition: {
        stage: "estimate", mode: "zero_cost", currency: "USD", rounding_mode: "half_up",
        zero_cost_reason: "Complimentary group amenity"
      }
    }
    definition = source.supplier_cost_definitions.find_by!(stage: "estimate")

    post forecast_ready_departure_arrangement_cost_definition_path(
      @departure, @arrangement, source, definition
    ), params: { lock_version: definition.lock_version }

    assert definition.reload.forecast_ready?
    assert_redirected_to departure_arrangement_costs_workspace_path(
      @departure, @arrangement, anchor: "definition-#{definition.id}"
    )
  end

  test "administrator creates an item-wide source when occurrence and resource selects are blank" do
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Cabin", category: "lodging", position: 1
    )
    sign_in_as @admin

    assert_difference -> { @version.supplier_cost_sources.count }, 1 do
      post departure_arrangement_item_costs_path(@departure, @arrangement, item), params: {
        idempotency_key: SecureRandom.uuid, version_lock_version: @version.lock_version,
        supplier_cost_source: {
          label: "01 Base", charging_supplier_id: @supplier.id,
          service_occurrence_id: "", supplier_resource_id: ""
        }
      }
    end
    source = @version.supplier_cost_sources.find_by!(label: "01 Base")
    assert_equal item.id, source.arrangement_item_id
    assert_nil source.service_occurrence_id
    assert_nil source.supplier_resource_id
    assert_redirected_to departure_arrangement_item_costs_workspace_path(
      @departure, @arrangement, item, anchor: "cost-source-#{source.id}"
    )
  end

  test "guided setup stores user-facing percentage and redirects through review" do
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Excursion", category: "lodging", position: 1
    )
    sign_in_as @admin

    post departure_arrangement_item_cost_setup_path(@departure, @arrangement, item), params: {
      idempotency_key: SecureRandom.uuid, version_lock_version: @version.lock_version,
      supplier_cost_source: { label: "Commission", charging_supplier_id: @supplier.id },
      supplier_cost_definition: {
        stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      },
      supplier_cost_component: {
        label: "Expected commission", economic_role: "expected_commission",
        calculation_kind: "percentage", percentage: "16",
        percentage_treatment: "additive", pass_through: "0"
      }
    }
    component = SupplierCostComponent.find_by!(label: "Expected commission")
    assert_equal BigDecimal("0.16"), component.rate
    assert component.supplier_cost_definition.working?
    assert_redirected_to departure_arrangement_item_cost_definition_review_path(
      @departure, @arrangement, item, component.supplier_cost_definition.supplier_cost_source,
      component.supplier_cost_definition
    )

    follow_redirect!
    assert_response :success
    assert_match "Readiness attestation", response.body
    assert_select "form[action=?]", forecast_ready_departure_arrangement_item_cost_definition_path(
      @departure, @arrangement, item, component.supplier_cost_definition.supplier_cost_source,
      component.supplier_cost_definition
    )
  end

  test "cost workspace routes readiness through review and exposes category edit controls" do
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Cabin", category: "lodging", position: 1
    )
    category = CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      version_lock_version: @version.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Adult" }
    ).call.record
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { arrangement_item_id: item.id, charging_supplier_id: @supplier.id, label: "Fare" }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source:, source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { stage: "estimate", mode: "zero_cost", currency: "USD", zero_cost_reason: "Included" }
    ).call.record
    sign_in_as @admin

    get departure_arrangement_item_costs_workspace_path(@departure, @arrangement, item)
    assert_response :success
    assert_select "a", text: "Review definition", count: 1
    assert_select "input[type=submit][value='Mark forecast ready']", count: 0
    assert_select "summary", text: "Edit participant category", count: 1
    assert_select "form[action=?]", departure_arrangement_item_participant_category_path(
      @departure, @arrangement, item, category
    ), minimum: 2

    get departure_arrangement_item_cost_definition_review_path(
      @departure, @arrangement, item, source, definition
    )
    assert_response :success
    assert_match "Known zero", response.body

    patch departure_arrangement_item_participant_category_path(
      @departure, @arrangement, item, category
    ), params: {
      supplier_cost_participant_category: { label: "Guest", lock_version: category.lock_version }
    }
    assert_equal "Guest", category.reload.label
    delete departure_arrangement_item_participant_category_path(
      @departure, @arrangement, item, category
    ), params: { version_lock_version: @version.reload.lock_version }
    assert_not SupplierCostParticipantCategory.exists?(category.id)
  end

  test "guided setup preserves entered values on validation failure" do
    sign_in_as @admin

    post departure_arrangement_cost_setup_path(@departure, @arrangement), params: {
      idempotency_key: SecureRandom.uuid, version_lock_version: @version.lock_version,
      supplier_cost_source: { label: "Remember this", charging_supplier_id: @supplier.id },
      supplier_cost_definition: {
        stage: "estimate", mode: "calculated", currency: "USD", rounding_mode: "half_up"
      },
      supplier_cost_component: {
        label: "Broken unit rate", economic_role: "supplier_charge",
        calculation_kind: "unit_rate", amount: "12.50", quantity_basis: ""
      }
    }

    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Quantity basis/
    assert_select "input[name='supplier_cost_source[label]'][value='Remember this']"
    assert_select "input[name='supplier_cost_component[label]'][value='Broken unit rate']"
    assert_not @version.supplier_cost_sources.exists?(label: "Remember this")
  end

  test "staff workspace exposes occupancy selectors base links and currency amounts" do
    item = @arrangement.arrangement_items.create!(agency: @agency, departure: @departure)
    @version.arrangement_item_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      arrangement_item: item, name: "Cabin", category: "lodging", position: 1
    )
    source = CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { arrangement_item_id: item.id, charging_supplier_id: @supplier.id, label: "O1 terms" }
    ).call.record
    definition = CreateSupplierCostDefinition.new(
      agency: @agency, actor: @admin, source: source, source_lock_version: source.lock_version,
      idempotency_key: SecureRandom.uuid,
      attributes: { stage: "contracted", mode: "calculated", currency: "USD", rounding_mode: "half_up" }
    ).call.record
    fare = CreateSupplierCostComponent.new(
      agency: @agency, actor: @admin, definition: definition,
      definition_lock_version: definition.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: {
        label: "Fare", economic_role: "supplier_charge", calculation_kind: "fixed",
        amount_minor_units: 10_000, pass_through: false
      }
    ).call.record
    CreateSupplierCostParticipantCategory.new(
      agency: @agency, actor: @admin, arrangement_item: item,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Adult" }
    ).call
    sign_in_as @admin

    get departure_arrangement_item_costs_workspace_path(@departure, @arrangement, item)
    assert_response :success
    assert_match "Amount (USD)", response.body
    assert_match "Occupancy position from", response.body
    assert_match "Base components", response.body
    assert_match "Edit component", response.body
    assert_match "Remove", response.body
    assert_select "input[name=?]", "supplier_cost_component[amount]"
    assert_select "input[name=?]", "supplier_cost_component[percentage]"
    assert_select "select[name=?]", "base_links[][direction]"

    post departure_arrangement_item_cost_definition_components_path(
      @departure, @arrangement, item, source, definition
    ), params: {
      idempotency_key: SecureRandom.uuid,
      definition_lock_version: definition.reload.lock_version,
      supplier_cost_component: {
        label: "Commission", economic_role: "expected_commission", calculation_kind: "percentage",
        percentage: "15", percentage_treatment: "additive", pass_through: "0"
      },
      base_links: [
        { base_component_id: fare.id, direction: "add" },
        { base_component_id: "", direction: "add" }
      ]
    }
    commission = definition.supplier_cost_components.find_by!(label: "Commission")
    assert_equal 1, commission.supplier_cost_component_bases.count
    assert_equal BigDecimal("0.15"), commission.rate
    assert_equal "add", commission.supplier_cost_component_bases.first.direction
    assert_redirected_to departure_arrangement_item_costs_workspace_path(
      @departure, @arrangement, item, anchor: "component-#{commission.id}"
    )
  end

  test "viewer sees cost workspace without mutation controls and cannot post" do
    source = create_source
    sign_in_as @viewer

    get departure_arrangement_path(@departure, @arrangement)
    assert_response :success
    assert_match "Planning status", response.body
    assert_match "Arrangement costs", response.body
    assert_select "summary", text: "Add cost source", count: 0

    get departure_arrangement_costs_workspace_path(@departure, @arrangement)
    assert_response :success
    assert_match source.label, response.body
    assert_select "summary", text: "Add cost source", count: 0
    assert_select "button", text: "Remove", count: 0

    assert_no_difference -> { @version.supplier_cost_sources.count } do
      post departure_arrangement_costs_path(@departure, @arrangement), params: {
        idempotency_key: SecureRandom.uuid, version_lock_version: @version.lock_version,
        supplier_cost_source: { label: "Viewer write", charging_supplier_id: @supplier.id }
      }
    end
    assert_redirected_to root_path
  end

  test "cross-agency parent chain returns not found" do
    other_agency = agencies(:cove)
    other_admin = agency_users(:cove_admin)
    other_departure = other_agency.departures.create!(
      name: "Foreign cost", starts_on: Date.new(2027, 6, 1), ends_on: Date.new(2027, 6, 2),
      time_zone: "America/New_York", operating_currency: "USD",
      responsible_office: offices(:cove_main), responsible_agency_user: other_admin
    )
    other_supplier = other_agency.suppliers.create!(
      kind: "organization", supplier_reference: "SUP-739992", display_name: "Foreign Supplier"
    )
    other_arrangement = other_agency.supplier_arrangements.create!(
      departure: other_departure, contracting_supplier: other_supplier, name: "Foreign arrangement"
    )
    other_arrangement.versions.create!(agency: other_agency, departure: other_departure, version_number: 1)
    sign_in_as @admin

    post departure_arrangement_costs_path(other_departure, other_arrangement), params: {
      idempotency_key: SecureRandom.uuid, version_lock_version: 0,
      supplier_cost_source: { label: "Foreign write", charging_supplier_id: other_supplier.id }
    }
    assert_response :not_found
  end

  test "cross-agency source definition and component ids return not found under local parents" do
    local_source = create_source
    local_definition = local_source.supplier_cost_definitions.create!(
      agency: @agency, departure: @departure, supplier_arrangement: @arrangement,
      supplier_arrangement_version: @version, stage: "estimate", mode: "calculated", currency: "USD"
    )
    other_agency = agencies(:cove)
    other_admin = agency_users(:cove_admin)
    other_departure = other_agency.departures.create!(
      name: "Foreign nested costs", starts_on: Date.new(2027, 7, 1), ends_on: Date.new(2027, 7, 2),
      time_zone: "America/New_York", operating_currency: "USD",
      responsible_office: offices(:cove_main), responsible_agency_user: other_admin
    )
    other_supplier = other_agency.suppliers.create!(
      kind: "organization", supplier_reference: "SUP-739993", display_name: "Foreign Nested Supplier"
    )
    other_arrangement = other_agency.supplier_arrangements.create!(
      departure: other_departure, contracting_supplier: other_supplier, name: "Foreign nested arrangement"
    )
    other_version = other_arrangement.versions.create!(
      agency: other_agency, departure: other_departure, version_number: 1
    )
    foreign_source = other_version.supplier_cost_sources.create!(
      agency: other_agency, departure: other_departure, supplier_arrangement: other_arrangement,
      charging_supplier: other_supplier, label: "Foreign source", position: 1
    )
    foreign_definition = foreign_source.supplier_cost_definitions.create!(
      agency: other_agency, departure: other_departure, supplier_arrangement: other_arrangement,
      supplier_arrangement_version: other_version, stage: "estimate", mode: "calculated", currency: "USD"
    )
    foreign_component = foreign_definition.supplier_cost_components.create!(
      agency: other_agency, departure: other_departure, supplier_arrangement: other_arrangement,
      supplier_arrangement_version: other_version, label: "Foreign component",
      economic_role: "supplier_charge", calculation_kind: "fixed",
      amount_minor_units: 5_000, pass_through: false, position: 1
    )
    sign_in_as @admin

    post departure_arrangement_cost_definitions_path(
      @departure, @arrangement, foreign_source
    ), params: { idempotency_key: SecureRandom.uuid, source_lock_version: 0 }
    assert_response :not_found

    patch departure_arrangement_cost_definition_path(
      @departure, @arrangement, local_source, foreign_definition
    ), params: { supplier_cost_definition: { lock_version: 0 } }
    assert_response :not_found

    patch departure_arrangement_cost_definition_component_path(
      @departure, @arrangement, local_source, local_definition, foreign_component
    ), params: { supplier_cost_component: { lock_version: 0 } }
    assert_response :not_found
  end

  private

  def create_source
    CreateSupplierCostSource.new(
      agency: @agency, actor: @admin, arrangement: @arrangement,
      version_lock_version: @version.reload.lock_version, idempotency_key: SecureRandom.uuid,
      attributes: { label: "Visible fee", charging_supplier_id: @supplier.id }
    ).call.record
  end
end
