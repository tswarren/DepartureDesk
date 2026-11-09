require "test_helper"

# S-19 and the booking's supplier status (INV-33 to INV-37; step 7 plan, question 7).
class SupplierReservationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    set_clock Time.utc(2027, 1, 20, 15)
    @departure = @alpha.departure
    @booking = @alpha.bookings.fetch("BK-104")
    @hotel = @alpha.arrangements.fetch(:hotel)
    @nights = @booking.choice_selections.select { |selection| selection.inventory_group.label.in?([ "Nov 2 Harbor Double", "Nov 3 Harbor Double" ]) }
  end

  test "staff with Supplier arrangements start a request from the booking and record the answer on the arrangement" do
    sign_in_as @admin
    post client_booking_supplier_reservations_path(@booking), params: { arrangement_id: @hotel.id, selection_ids: @nights.map(&:id), step: "rooms" }
    assert_redirected_to client_booking_path(@booking, step: "rooms", anchor: "supplier-requests")
    reservation = @booking.supplier_reservations.sole

    get new_departure_arrangement_supplier_reservation_acceptance_path(@departure, @hotel, reservation)
    assert_select "h1", text: "Record the supplier's acceptance"
    post departure_arrangement_supplier_reservation_acceptance_path(@departure, @hotel, reservation),
      params: { lock_version: reservation.lock_version, supplier_reservation: { supplier_reference: "", responded_on: "2027-01-20" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Supplier reference is required/

    post departure_arrangement_supplier_reservation_acceptance_path(@departure, @hotel, reservation),
      params: { lock_version: reservation.lock_version, supplier_reservation: { supplier_reference: "SHH-24117", responded_on: "2027-01-20" } }
    assert_redirected_to departure_arrangement_reservations_path(@departure, @hotel)
    assert reservation.reload.status_confirmed?
  end

  test "baseline staff see each service's supplier status but can't start or record a request" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get client_booking_path(@booking, step: "rooms")
    assert_select "#supplier-requests td", text: /Request from the supplier/
    assert_select "#request-#{@hotel.id}", count: 0
    assert_select "#supplier-requests p", text: /Someone with Supplier arrangements starts it/
    post client_booking_supplier_reservations_path(@booking), params: { arrangement_id: @hotel.id, selection_ids: @nights.map(&:id) }
    assert_redirected_to root_path
    assert_empty @booking.supplier_reservations.reload
  end

  test "the roster counts services awaiting the supplier" do
    RequestSupplierReservation.new(agency: @agency, actor: @admin, booking: @booking, arrangement: @hotel, selection_ids: @nights.map(&:id)).call
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_bookings_path(@departure)
    row = css_select("tbody tr").find { |tr| tr.text.include?(@booking.booking_reference) }
    assert_includes row.text, "2 awaiting supplier"
  end

  test "other agencies get not found" do
    reservation = RequestSupplierReservation.new(agency: @agency, actor: @admin, booking: @booking, arrangement: @hotel, selection_ids: @nights.map(&:id)).call.record
    sign_in_as agency_users(:cove_admin)
    get new_departure_arrangement_supplier_reservation_acceptance_path(@departure, @hotel, reservation)
    assert_response :not_found
    post client_booking_supplier_reservations_path(@booking), params: { arrangement_id: @hotel.id, selection_ids: @nights.map(&:id) }
    assert_response :not_found
  end
end
