require "test_helper"

class SupplierArrangementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:one)
    @admin = users(:one)
    @supplier = parties(:organization_one)
    assign_supplier_role!(@supplier, actor: @admin) unless @supplier.supplier_profile
    @departure = create_departure!(@agency, actor: @admin, name: "Controller Supplier Planning")
    StartDeparturePlanning.new(agency: @agency, actor: @admin, departure: @departure).call
    sign_in_as @admin
  end

  test "index creates a draft arrangement and show renders supplier planning panels" do
    get departure_supplier_arrangements_path(@departure)
    assert_response :success
    assert_select "h1", text: "Controller Supplier Planning"
    assert_select "a", text: "Supplier planning"

    assert_difference -> { SupplierArrangement.count }, 1 do
      post departure_supplier_arrangements_path(@departure), params: {
        supplier_party_id: @supplier.id,
        name: "Controller Cruise Agreement",
        lock_version: @departure.lock_version
      }
    end

    arrangement = SupplierArrangement.order(:created_at).last
    assert_redirected_to departure_supplier_arrangement_path(@departure, arrangement)

    get departure_supplier_arrangement_path(@departure, arrangement)
    assert_response :success
    assert_select "h1", text: "Controller Cruise Agreement"
    assert_select "#resources"
    assert_select "#reservations"
    assert_select "#capacity"
    assert_select "#clauses"
  end

  test "nested workflow records resource occurrence hold confirmation reservation and transfer freeze UI" do
    arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_party: @supplier, name: "Workflow Agreement").call.supplier_arrangement

    assert_difference -> { SupplierResource.count }, 1 do
      post create_resource_departure_supplier_arrangement_path(@departure, arrangement), params: {
        name: "Balcony Cabins",
        resource_kind: "cabin_category",
        capacity_unit: "cabin",
        lock_version: arrangement.lock_version
      }
    end
    resource = arrangement.supplier_resources.first

    assert_difference -> { SupplierServiceOccurrence.count }, 1 do
      post create_occurrence_departure_supplier_arrangement_path(@departure, arrangement), params: {
        resource_id: resource.id,
        occurrence_kind: "typed_segment",
        segment_type: "sailing",
        segment_identifier: "MAIN"
      }
    end
    occurrence = resource.supplier_service_occurrences.first

    assert_difference -> { SupplierCapacityPosition.count }, 1 do
      post hold_capacity_departure_supplier_arrangement_path(@departure, arrangement), params: {
        resource_id: resource.id,
        service_occurrence_id: occurrence.id,
        quantity: 12,
        guaranteed_quantity: 12,
        reason: "Initial cabin block",
        idempotency_key: SecureRandom.uuid
      }
    end

    assert_difference -> { SupplierConfirmation.count }, 1 do
      post record_confirmation_departure_supplier_arrangement_path(@departure, arrangement), params: {
        issuer_party_id: @supplier.id,
        identifier_type: "supplier_confirmation",
        context: "supplier_portal",
        raw_value: "CRU-CTRL-1"
      }
    end

    assert_difference -> { SupplierReservation.count }, 1 do
      post create_reservation_departure_supplier_arrangement_path(@departure, arrangement), params: {
        name: "Cabin request 101",
        resource_ids: [ resource.id ],
        lock_version: arrangement.lock_version
      }
    end
    reservation = arrangement.supplier_reservations.first

    post confirm_reservation_departure_supplier_arrangement_path(@departure, arrangement), params: {
      reservation_id: reservation.id,
      reservation_lock_version: reservation.lock_version,
      without_identifier_reason: "Supplier confirmed by phone"
    }
    assert_redirected_to departure_supplier_arrangement_path(@departure, arrangement, anchor: "reservations")
    assert reservation.reload.confirmed?

    get departure_path(@departure)
    assert_response :success
    assert_select ".dd-alert--warning", text: /Office transfer is unavailable/
    assert_select "input[type=submit][disabled][value='Transfer office']"
  end
end
