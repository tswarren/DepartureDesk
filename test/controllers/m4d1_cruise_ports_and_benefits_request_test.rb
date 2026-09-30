# frozen_string_literal: true

require "test_helper"

class M4d1CruisePortsAndBenefitsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @contractor = create_capacity_supplier(@agency, "Celebrity Cruises")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @arrangement = CreateCruiseSailingSetup.new(
      agency: @agency,
      actor: @staff,
      departure: @departure,
      arrangement_attributes: {
        name: "Celebrity group agreement",
        contracting_supplier_id: @contractor.id
      },
      item_attributes: { name: "Celebrity Beyond" },
      occurrence_attributes: {
        name: "Western Caribbean",
        starts_on: "2027-11-06",
        ends_on: "2027-11-13",
        time_zone: "America/New_York"
      },
      idempotency_key: SecureRandom.uuid
    ).call.record.arrangement
  end

  test "viewer can read commercial benefits and cannot save them" do
    version = @arrangement.versions.sole
    RecordCruiseCommercialBenefit.new(
      agency: @agency, actor: @staff, arrangement: @arrangement,
      term_type: "tour_conductor_credit",
      body: "1 cruise-only credit per 16 qualifying guests.",
      source_citation: "July 2025 Celebrity Groups brochure",
      version_lock_version: version.lock_version,
      idempotency_key: SecureRandom.uuid
    ).call

    sign_in_as @viewer
    get departure_arrangement_cruise_agreement_path(@departure, @arrangement)
    assert_response :success
    assert_select "h2", text: "Benefits"
    assert_match "Agreement benefits are recorded for reference. DepartureDesk does not calculate earned entitlements.", response.body
    assert_match "1 cruise-only credit per 16 qualifying guests.", response.body
    assert_no_match "Add Tour-conductor credit", response.body
    assert_no_match "Save Tour-conductor credit", response.body

    assert_no_difference -> { SupplierArrangementCommercialBenefitDefinition.count } do
      post departure_arrangement_cruise_commercial_benefits_path(@departure, @arrangement), params: {
        idempotency_key: SecureRandom.uuid,
        version_lock_version: version.lock_version,
        commercial_benefit: {
          term_type: "group_amenity_program",
          body: "Four group points.",
          source_citation: "July 2025 Celebrity Groups brochure"
        }
      }
    end
    assert_redirected_to root_path
  end

  test "another agency cruise is not found" do
    other = agencies(:cove)
    foreign_departure = create_capacity_departure(other, name: "Foreign Cruise")
    foreign_supplier = create_capacity_supplier(other, "Foreign Line")
    foreign = CreateCruiseSailingSetup.new(
      agency: other, actor: agency_users(:cove_admin), departure: foreign_departure,
      arrangement_attributes: { name: "Foreign sailing", contracting_supplier_id: foreign_supplier.id },
      item_attributes: { name: "Foreign Ship" },
      occurrence_attributes: {
        name: "Foreign itinerary", starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "UTC"
      },
      idempotency_key: SecureRandom.uuid
    ).call.record.arrangement

    sign_in_as @staff
    get departure_arrangement_cruise_path(foreign_departure, foreign)
    assert_response :not_found
  end
end
