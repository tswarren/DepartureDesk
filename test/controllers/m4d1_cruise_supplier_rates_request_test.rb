# frozen_string_literal: true

require "test_helper"

class M4d1CruiseSupplierRatesRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @setup = create_cruise_with_cabin
    @arrangement = @setup[:arrangement]
    @resource = @setup[:resource]
    @version = @arrangement.versions.sole
  end

  test "workspace links to add supplier rates and rate page saves smith terms" do
    sign_in_as @staff

    get departure_arrangement_cruise_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-rates-heading"
    assert_select "a", text: "Open Supplier rates"
    assert_select "a", text: "Add Supplier rates", count: 0

    get departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    assert_response :success
    assert_select "#cruise-supplier-rate-terms"
    assert_select "a[href=?]", departure_arrangement_cruise_supplier_rates_path(@departure, @arrangement), text: "Supplier rates"
    assert_select "#cruise-rate-stage-status", text: /Not recorded/
    assert_select "#commission_method option", count: 3
    assert_select "#commission_method option", text: "Not provided yet"
    assert_select "#commission_method option", text: "Dollar amount"
    assert_select "#commission_method option", text: "Percentage"
    assert_select "button", text: "Add rate profile"
    assert_select "button", text: "Add component"
    assert_no_match(/Use the same commission rate for every profile/, response.body)
    form = css_select("#cruise-supplier-rate-terms").first
    state = JSON.parse(form["data-cruise-rate-matrix-initial-state-value"])
    assert_equal %w[first_second additional single_supplement], state["profiles"].map { |profile| profile["key"] }
    assert_select ".dd-cruise-rate-narrow"
    assert_no_match(/\bquantity_basis\b|\bSupplierCost\b/, response.body)

    post preview_departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: {
      version_lock_version: @version.lock_version,
      stage: "estimate",
      profiles: {
        "0" => { family: "first_second", key: "first_second" },
        "1" => { family: "every_traveler", key: "every_traveler" }
      },
      cells: {
        "base_fare:first_second" => "1624.00",
        "nccf:every_traveler" => "320.00"
      },
      commission: { method: "not_provided" }
    }, headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    assert body["illustrations"].is_a?(Array)
    assert body["illustrations"].any?

    post departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: {
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid,
      stage: "estimate",
      profiles: %w[first_second additional every_traveler single_supplement],
      cells: {
        "base_fare:first_second" => "1624.00",
        "base_fare:additional" => "406.00",
        "base_fare:single_supplement" => "1624.00",
        "nccf:every_traveler" => "320.00",
        "discount:first_second" => "150.00",
        "discount:additional" => "37.50",
        "taxes_fees:every_traveler" => "137.00"
      },
      commission: { method: "not_provided" }
    }

    assert_redirected_to departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    follow_redirect!
    assert_response :success
    assert_match(/\$3,862\.00|386200/, response.body)
    assert_match(/Expected commission is not recorded/, response.body)
    assert_no_match(/\$0\.00/, response.body)
  end

  test "percentage commission preview reports the profile basis and a shared rate stays one component" do
    sign_in_as @staff

    post preview_departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: canonical_percentage_params, headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    first_second = body.fetch("profile_commissions").find { |row| row["key"] == "first_second" }
    assert_equal "$1,583.00", first_second["commissionable"]
    assert_equal "$237.45", first_second["expected_commission"]
    assert body["illustrations"].any?
    assert body["illustrations"].none? { |row| row["commission"] == "$0.00" }

    post departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: canonical_percentage_params.merge(idempotency_key: SecureRandom.uuid)
    assert_response :redirect
    definition = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.definition
    commissions = definition.supplier_cost_components.where(economic_role: "expected_commission")
    assert_equal 1, commissions.count
    assert_equal "percentage", commissions.first.calculation_kind
    assert_in_delta 0.15, commissions.first.rate.to_f, 0.0001
  end

  test "dollar commission preview shows the entered amount without a basis" do
    sign_in_as @staff

    post preview_departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    ), params: {
      version_lock_version: @version.lock_version,
      stage: "estimate",
      profiles: {
        "0" => { family: "first_second", key: "first_second" },
        "1" => { family: "additional", key: "additional" }
      },
      cells: { "base_fare:first_second" => "100.00" },
      commission: {
        method: "dollar",
        amounts: { "first_second" => "25.00", "additional" => "10.00" }
      }
    }, headers: { "Accept" => "application/json" }
    assert_response :success
    body = JSON.parse(response.body)
    first_second = body.fetch("profile_commissions").find { |row| row["key"] == "first_second" }
    assert_equal false, first_second["basis_recorded"]
    assert_nil first_second["commissionable"]
    assert_equal "$25.00", first_second["expected_commission"]
  end

  test "a commission basis that differs by profile opens advanced planning" do
    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      profiles: [
        { family: "first_second", key: "first_second" },
        { family: "additional", key: "additional" }
      ],
      cells: {
        "base_fare:first_second" => "100.00",
        "base_fare:additional" => "40.00"
      },
      commission: {
        method: "percentage",
        percentage: "15",
        add_cells: %w[base_fare:first_second]
      },
      stage: "estimate",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_as @staff
    get departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, @arrangement, @resource
    )
    assert_response :success
    assert_match(/Commissionable components differ by rate profile/, response.body)
    assert_select "#cruise-supplier-rate-terms", count: 0
    assert_select "a", text: "Open advanced cost planning"
  end

  test "supplier rates landing keeps a ready estimate distinct from the contracted activation finding" do
    sign_in_as @staff
    get departure_arrangement_cruise_supplier_rates_path(@departure, @arrangement)
    assert_response :success
    assert_select "#cruise-step-rates[aria-current=page]"
    assert_match "1 cabin category · 1 not recorded", response.body
    assert_select "#cruise-supplier-rates-table td", text: /Not recorded/

    CreateCruiseSupplierRateSchedule.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      terms: {
        first_second_fare: "1624.00",
        additional_fare: "406.00",
        single_supplement: "1624.00",
        nccf: "320.00",
        first_second_discount: "150.00",
        additional_discount: "37.50",
        taxes_fees: "137.00"
      },
      commission: { method: "not_provided" },
      stage: "estimate",
      version_lock_version: @version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call
    SetCruiseSupplierOccupancyPlan.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      expected_cabins: { double: 1 },
      version_lock_version: @version.reload.lock_version
    ).call
    definition = DetectCruiseSupplierRateShape.new(
      agency: @agency, arrangement: @arrangement, resource: @resource
    ).call.definition
    MarkCruiseSupplierRateScheduleForecastReady.new(
      agency: @agency,
      actor: @staff,
      arrangement: @arrangement,
      resource: @resource,
      definition_lock_version: definition.lock_version,
      readiness_provenance: "Signed terms",
      confirm_omissions: true
    ).call

    get departure_arrangement_cruise_supplier_rates_path(@departure, @arrangement)
    assert_response :success
    assert_match "1 cabin category · 1 estimate", response.body
    assert_select "#cruise-supplier-rates-table td", text: /Estimate/
    assert_select "#cruise-supplier-rates-table td", text: /Ready/
    assert_select "#cruise-supplier-rates-attention", text: /Record contracted Supplier rates for O1/
    assert_select "a[href=?]",
      departure_arrangement_cruise_cabin_category_supplier_rates_path(
        @departure, @arrangement, @resource, stage: "estimate"
      ),
      text: "Prime Oceanview"
    assert_match "Single occupancy", response.body
    assert_match "Double occupancy", response.body
    assert_match "Triple occupancy", response.body

    get departure_arrangement_cruise_activation_path(@departure, @arrangement)
    assert_response :success
    rate_links = css_select("a").select { |link| link.text == "Review Supplier rates" }
    assert rate_links.any?
    assert rate_links.none? { |link| link["href"].include?("#cruise-rates") }
    assert_select "a[href=?]",
      departure_arrangement_cruise_cabin_category_supplier_rates_path(
        @departure, @arrangement, @resource, stage: "estimate"
      ),
      text: "Review Supplier rates"
  end

  test "cross-agency supplier rates return not found" do
    other = agencies(:cove)
    foreign_departure = create_capacity_departure(other, name: "Foreign Cruise")
    foreign_supplier = create_capacity_supplier(other, "Foreign Line")
    foreign = CreateCruiseSailingSetup.new(
      agency: other,
      actor: agency_users(:cove_admin),
      departure: foreign_departure,
      arrangement_attributes: {
        name: "Foreign agreement",
        contracting_supplier_id: foreign_supplier.id
      },
      item_attributes: { name: "Foreign ship" },
      occurrence_attributes: {
        name: "Foreign sailing",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    foreign_arrangement = foreign.record.arrangement
    foreign_version = foreign_arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: other,
      actor: agency_users(:cove_admin),
      arrangement: foreign_arrangement,
      resource_attributes: { name: "Inside", supplier_code: "IN", maximum_occupancy: 2 },
      pool_attributes: { inventory_mode: "block", proposed_opening_quantity: 2 },
      version_lock_version: foreign_version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_as @staff
    get departure_arrangement_cruise_cabin_category_supplier_rates_path(
      @departure, foreign_arrangement, cabin.record.resource
    )
    assert_response :not_found
  end

  private

  def canonical_percentage_params
    {
      version_lock_version: @version.lock_version,
      stage: "estimate",
      profiles: {
        "0" => { family: "first_second", key: "first_second" },
        "1" => { family: "additional", key: "additional" },
        "2" => { family: "single_supplement", key: "single_supplement" }
      },
      cells: {
        "base_fare:first_second" => "2533.00",
        "base_fare:additional" => "10.00",
        "base_fare:single_supplement" => "2533.00",
        "nccf:first_second" => "320.00",
        "nccf:single_supplement" => "320.00",
        "discount:first_second" => "950.00",
        "discount:single_supplement" => "950.00",
        "taxes_fees:first_second" => "134.26",
        "taxes_fees:single_supplement" => "134.26"
      },
      commission: {
        method: "percentage",
        shared: "1",
        percentage: "15",
        add_cells: %w[base_fare:first_second base_fare:additional base_fare:single_supplement],
        subtract_cells: %w[discount:first_second discount:single_supplement]
      }
    }
  end

  def create_cruise_with_cabin
    provider = create_capacity_supplier(@agency, "Celebrity Ship Ops")
    contact = @contractor.contacts.create!(
      agency: @agency, first_name: "Group", last_name: "Desk", status: "active"
    )
    sailing = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id,
        supplier_contact_id: contact.id
      },
      item_attributes: {
        name: "Celebrity Beyond",
        default_service_provider_id: provider.id
      },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call
    arrangement = sailing.record.arrangement
    version = arrangement.versions.sole
    cabin = CreateCruiseCabinCategorySetup.new(
      agency: @agency,
      actor: @staff,
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
    { arrangement: arrangement, resource: cabin.record.resource }
  end
end
