require "test_helper"

class SupplierPlanningScenarioTest < ActiveSupport::TestCase
  setup do
    @agency = agencies(:one)
    @admin = users(:one)
    @staff = users(:staff_one)
    @supplier = parties(:organization_one)
    assign_supplier_role!(@supplier, actor: @admin) unless @supplier.supplier_profile
  end

  test "Napa supplier planning proves fixed coach stepped resource forecast and exposure without client trips" do
    departure = napa_wine_country_departure!(actor: @admin)
    arrangement = create_arrangement!(departure:, name: "Napa Coach Contract")
    coach = create_resource!(arrangement:, name: "30 Seat Motorcoach", resource_kind: "coach", capacity_unit: "seat")
    coach_segment = create_occurrence!(resource: coach, occurrence_kind: "typed_segment", segment_type: "coach_leg", segment_identifier: "NAPA-LOOP")
    HoldSupplierCapacity.new(agency: @agency, actor: @staff, resource: coach, service_occurrence: coach_segment, quantity: 30, guaranteed_quantity: 30, reason: "Thirty seat coach hold", idempotency_key: SecureRandom.uuid).call

    fixed_coach = create_fixed_term!(arrangement:, resource: coach, basis: "contracted", cost_category: "coach", quantity_basis: "resource", quantity_unit: "coach", amount_minor_units: 300_000, currency: "USD")
    ActivateSupplierCostTerm.new(agency: @agency, actor: @admin, term: fixed_coach).call
    CreateSupplierCommitment.new(agency: @agency, actor: @admin, governing_term: fixed_coach.reload, reason: "Coach contract guarantee").call

    vineyard = create_resource!(arrangement:, name: "Vineyard Participant Seats", resource_kind: "tour_inventory", capacity_unit: "seat")
    vineyard_segment = create_occurrence!(resource: vineyard, occurrence_kind: "typed_segment", segment_type: "vineyard_visit", segment_identifier: "DAY-2")
    HoldSupplierCapacity.new(agency: @agency, actor: @staff, resource: vineyard, service_occurrence: vineyard_segment, quantity: 30, reason: "Planning seats", idempotency_key: SecureRandom.uuid).call
    stepped = create_stepped_term!(arrangement:, resource: vineyard, service_occurrence: vineyard_segment, currency: "EUR")
    ActivateSupplierCostTerm.new(agency: @agency, actor: @admin, term: stepped).call

    eur_guarantee = create_minimum_guarantee_term!(arrangement:, resource: vineyard, service_occurrence: vineyard_segment, minimum_quantity: 15, unit_amount_minor_units: 8_000, currency: "EUR")
    ActivateSupplierCostTerm.new(agency: @agency, actor: @admin, term: eur_guarantee).call

    forecast = SupplierForecastCostReporter.call(agency: @agency, departure:)
    exposure = SupplierGuaranteeExposureReporter.call(agency: @agency, departure:)

    assert_equal 300_000, forecast.totals_by_currency.fetch("USD")
    assert_equal 367_500, forecast.totals_by_currency.fetch("EUR")
    assert_equal 300_000, exposure.monetary_totals_by_currency.fetch("USD")
    assert_equal 120_000, exposure.monetary_totals_by_currency.fetch("EUR")
    assert_equal 30, exposure.guaranteed_capacity_by_unit.fetch("seat")
    assert_equal 0, DefinedSupplierPlanningScenarioProbe.client_sale_tables
  end

  test "Smith supplier planning proves cruise guarantee hotel block nights and on request extensions without client trips" do
    departure = smith_family_reunion_departure!(actor: @admin)
    cruise = create_arrangement!(departure:, name: "Smith Cruise Agreement")
    cabins = create_resource!(arrangement: cruise, name: "Guaranteed Balcony Cabins", resource_kind: "cabin_category", capacity_unit: "cabin")
    sailing = create_occurrence!(resource: cabins, occurrence_kind: "typed_segment", segment_type: "sailing", segment_identifier: "MAIN")
    HoldSupplierCapacity.new(agency: @agency, actor: @staff, resource: cabins, service_occurrence: sailing, quantity: 12, guaranteed_quantity: 12, reason: "Guaranteed cruise cabin block", idempotency_key: SecureRandom.uuid).call
    cabin_term = create_minimum_guarantee_term!(arrangement: cruise, resource: cabins, service_occurrence: sailing, minimum_quantity: 12, unit_amount_minor_units: 150_000, currency: "USD")
    ActivateSupplierCostTerm.new(agency: @agency, actor: @admin, term: cabin_term).call
    CreateSupplierCommitment.new(agency: @agency, actor: @admin, governing_term: cabin_term.reload, reason: "Cruise cabin guarantee").call

    hotel = create_arrangement!(departure:, name: "Pre Cruise Hotel Block")
    rooms = create_resource!(arrangement: hotel, name: "Standard Group Night Rooms", resource_kind: "room_type", capacity_unit: "room")
    standard_night = create_occurrence!(resource: rooms, occurrence_kind: "night_slice", service_date: Date.new(2027, 7, 11), label: "Standard pre-cruise night")
    extension_night = create_occurrence!(resource: rooms, occurrence_kind: "night_slice", service_date: Date.new(2027, 7, 10), label: "Optional extension night")
    HoldSupplierCapacity.new(agency: @agency, actor: @staff, resource: rooms, service_occurrence: standard_night, quantity: 10, guaranteed_quantity: 6, reason: "Standard room block", idempotency_key: SecureRandom.uuid).call
    RequestSupplierCapacity.new(agency: @agency, actor: @staff, resource: rooms, service_occurrence: extension_night, quantity: 5, reason: "On-request optional extension rooms", idempotency_key: SecureRandom.uuid).call

    standard_position = SupplierCapacityPosition.find_by!(resource: rooms, service_occurrence: standard_night)
    extension_position = SupplierCapacityPosition.find_by!(resource: rooms, service_occurrence: extension_night)

    assert_equal 10, standard_position.agency_held
    assert_equal 6, standard_position.guaranteed
    assert_equal 0, extension_position.agency_held
    assert_equal 5, extension_position.pending_request
    assert_equal 12, SupplierGuaranteeExposureReporter.call(agency: @agency, departure:).guaranteed_capacity_by_unit.fetch("cabin")
    assert_equal 0, DefinedSupplierPlanningScenarioProbe.client_sale_tables
  end

  private

  def create_arrangement!(departure:, name:)
    CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure:, supplier_party: @supplier, name:).call.supplier_arrangement
  end

  def create_resource!(arrangement:, name:, resource_kind:, capacity_unit:)
    CreateSupplierResource.new(agency: @agency, actor: @staff, arrangement:, name:, resource_kind:, capacity_unit:).call.supplier_resource
  end

  def create_occurrence!(resource:, occurrence_kind:, service_date: nil, segment_type: nil, segment_identifier: nil, label: nil)
    CreateSupplierServiceOccurrence.new(
      agency: @agency,
      actor: @staff,
      resource:,
      occurrence_kind:,
      service_date:,
      segment_type: occurrence_kind == "typed_segment" ? segment_type : nil,
      segment_identifier: occurrence_kind == "typed_segment" ? segment_identifier : nil,
      label:
    ).call.supplier_service_occurrence
  end

  def create_fixed_term!(arrangement:, resource:, basis:, cost_category:, quantity_basis:, quantity_unit:, amount_minor_units:, currency:)
    CreateSupplierCostTerm.new(
      agency: @agency,
      actor: @admin,
      arrangement:,
      resource:,
      shape: "fixed",
      basis:,
      cost_category:,
      quantity_basis:,
      quantity_unit:,
      currency:,
      detail_attributes: { amount_minor_units: },
      provenance: "Scenario supplier worksheet"
    ).call.supplier_cost_term
  end

  def create_minimum_guarantee_term!(arrangement:, resource:, service_occurrence:, minimum_quantity:, unit_amount_minor_units:, currency:)
    CreateSupplierCostTerm.new(
      agency: @agency,
      actor: @admin,
      arrangement:,
      resource:,
      service_occurrence:,
      shape: "minimum_guarantee",
      basis: "contracted",
      cost_category: "supplier_guarantee",
      quantity_basis: "guaranteed_quantity",
      quantity_unit: resource.capacity_unit,
      currency:,
      detail_attributes: { minimum_quantity:, unit_amount_minor_units: },
      provenance: "Scenario guarantee schedule"
    ).call.supplier_cost_term
  end

  def create_stepped_term!(arrangement:, resource:, service_occurrence:, currency:)
    CreateSupplierCostTerm.new(
      agency: @agency,
      actor: @admin,
      arrangement:,
      resource:,
      service_occurrence:,
      shape: "stepped",
      basis: "contracted",
      cost_category: "vineyard_seats",
      quantity_basis: "qualifying_quantity",
      quantity_unit: "seat",
      currency:,
      evaluation_inputs: { "qualifying_quantity" => 30 },
      detail_attributes: {
        steps: [
          { band_start_quantity: 1, band_end_quantity: 15, unit_amount_minor_units: 9_000 },
          { band_start_quantity: 16, band_end_quantity: 30, unit_amount_minor_units: 7_500 }
        ]
      },
      provenance: "Scenario stepped supplier schedule"
    ).call.supplier_cost_term
  end
end

class DefinedSupplierPlanningScenarioProbe
  LATER = %w[
    client_trips
    service_components
    packages
    supplier_obligations
    supplier_payments
  ].freeze

  def self.client_sale_tables
    LATER.count { |name| ActiveRecord::Base.connection.data_source_exists?(name) }
  end
end
