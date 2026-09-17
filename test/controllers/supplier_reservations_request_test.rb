require "test_helper"

class SupplierReservationsRequestTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @viewer = agency_users(:harbor_viewer)
    @supplier = create_capacity_supplier(@agency, "Reservation Request Supplier")
    @departure = create_capacity_departure(@agency, name: "Reservation Request")
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "Reservation request",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
  end

  test "staff plans requests and withdraws a Supplier Reservation from arrangement routes" do
    activate_version_directly
    sign_in_as @staff

    get departure_arrangement_reservations_path(@departure, @arrangement)
    assert_response :success
    assert_select "a", text: "Create planned reservation"

    assert_difference -> { SupplierReservation.count }, 1 do
      post departure_arrangement_reservations_path(@departure, @arrangement), params: {
        idempotency_key: SecureRandom.uuid,
        supplier_reservation: {
          booking_supplier_id: @supplier.id,
          scopes: {
            "0" => { target_kind: "arrangement", label: "Whole block" }
          }
        }
      }
    end
    reservation = SupplierReservation.order(:created_at).last
    assert_redirected_to departure_arrangement_reservation_path(@departure, @arrangement, reservation)

    post request_booking_departure_arrangement_reservation_path(@departure, @arrangement, reservation), params: {
      idempotency_key: SecureRandom.uuid,
      request_event: {
        occurred_at: Time.current,
        channel: "portal",
        reference_note: "Portal request"
      }
    }
    assert_redirected_to departure_arrangement_reservation_path(@departure, @arrangement, reservation)
    assert_equal "requested", reservation.projection.reload.state

    post withdraw_departure_arrangement_reservation_path(@departure, @arrangement, reservation), params: {
      idempotency_key: SecureRandom.uuid,
      reason: "Supplier asked us to resend later"
    }
    assert_redirected_to departure_arrangement_reservation_path(@departure, @arrangement, reservation)
    assert_equal "withdrawn", reservation.projection.reload.state
  end

  test "viewer sees no mutation controls and cannot create" do
    sign_in_as @viewer

    get departure_arrangement_reservations_path(@departure, @arrangement)
    assert_response :success
    assert_select "a", text: "Create planned reservation", count: 0

    post departure_arrangement_reservations_path(@departure, @arrangement), params: {
      idempotency_key: SecureRandom.uuid,
      supplier_reservation: {
        booking_supplier_id: @supplier.id,
        scopes: { "0" => { target_kind: "arrangement" } }
      }
    }
    assert_redirected_to root_path
  end

  test "cross agency arrangement is not found" do
    cove = agencies(:cove)
    cove_supplier = create_capacity_supplier(cove, "Cove Reservation Supplier")
    cove_departure = create_capacity_departure(cove, name: "Cove Reservation")
    cove_graph = create_capacity_graph(
      agency: cove,
      departure: cove_departure,
      contractor: cove_supplier,
      provider: cove_supplier,
      prefix: "Cove reservation",
      capacity_management: "unmanaged"
    )
    sign_in_as @staff

    get departure_arrangement_reservations_path(cove_departure, cove_graph[:arrangement])
    assert_response :not_found
  end

  private

  def activate_version_directly
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end
end
