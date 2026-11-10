require "test_helper"

# S-25 and S-26: bookings are baseline work (ACC-30); other agencies get not found.
class BookingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_baseline_staff)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :held)
    @booking = @alpha.bookings.fetch("BK-104")
  end

  test "the roster lists each booking with its status, owner, cabin, travelers, subtotal and hold" do
    sign_in_as @staff
    get departure_bookings_path(@alpha.departure)
    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Bookings"
    row = css_select("tbody tr").find { |tr| tr.text.include?(@booking.booking_reference) }
    assert_includes row.text, "Sofia Bennett"
    assert_includes row.text, "Draft"
    assert_includes row.text, "Agency"
    assert_includes row.text, "S01"
    assert_includes row.text, "$12,570.00"
    assert_includes row.text, "Held until"
    assert_select "tfoot td", text: /10/
  end

  test "the workspace shows travelers, choices with positions, prices and the hold, and what confirmation needs" do
    sign_in_as @staff
    get client_booking_path(@booking)
    assert_select "h1", text: @booking.booking_reference
    assert_select "nav[aria-label='Booking steps'] a[aria-current=step]", text: /5 · Accept and confirm/
    assert_select "nav[aria-label='Booking steps'] a", text: /1 · Travelers\s+Done · 4 added/
    get client_booking_path(@booking, step: "travelers")
    assert_select "#travelers th[scope=row] a", text: "Milo Bennett"
    assert_select "#choices", count: 0
    get client_booking_path(@booking, step: "rooms")
    assert_select "#choices li", text: /Milo Bennett\s+· 4th guest/
    assert_select "#choices li", text: /Milo Bennett\s+· takes part without a position/
    get client_booking_path(@booking, step: "price")
    assert_select "#prices tfoot td", text: /\$12,570\.00/
    assert_select "#hold", count: 0
    assert_select "a", text: "Next: hold space"
    get client_booking_path(@booking, step: "hold")
    assert_select "#hold p", text: /Held until/
    assert_select "a", text: "Next: accept and confirm"
    get client_booking_path(@booking, step: "confirm")
    assert_select "#confirm a[href='#acceptance']", text: "Record the client's acceptance of the current price and terms."
  end

  test "the price summary says No charge for a free place and marks a traveler not on a service" do
    sign_in_as @staff
    get client_booking_path(@alpha.bookings.fetch("BK-105"), step: "price")
    tour = css_select("#prices tbody tr").find { |row| row.text.include?("Private Miami tour") }
    cells = tour.css("td.num").map { |cell| cell.text.squish }
    assert_equal [ "Mateo Rivera $150.00", "Elena Rivera —Not on this service", "Luca Rivera No charge" ], cells.first(3)
    assert_includes tour.text, "Not on this service: Elena Rivera"
    assert_select "#prices p.dd-field-hint", text: /No charge: on the service at no cost/
  end

  test "confirming lists what is missing with links, and staff hold, extend and release" do
    sign_in_as @staff
    post client_booking_confirmation_path(@booking)
    follow_redirect!
    assert_select "#form-error-summary a[href='#acceptance']"

    patch client_booking_hold_path(@booking)
    assert @booking.reload.hold_extended?
    delete client_booking_hold_path(@booking)
    assert_equal :none, @booking.reload.hold_state.first
    assert @booking.inventory_allocations.all?(&:state_released?)
  end

  test "a refused command redirects back to its section with its reason" do
    sign_in_as @staff
    patch client_booking_hold_path(@booking)
    patch client_booking_hold_path(@booking)
    assert_redirected_to client_booking_path(@booking, step: "hold", anchor: "hold")
    follow_redirect!
    assert_select ".dd-alert--danger", text: /already been extended once/
  end

  test "a trip books its Departure's package as a new draft" do
    sign_in_as @staff
    trip = @alpha.trips.fetch("BK-101")
    post client_trip_bookings_path(trip)
    booking = trip.client_bookings.order(:sequence).last
    assert_redirected_to client_booking_path(booking)
    assert_equal "#{trip.trip_reference}-2", booking.booking_reference
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get client_booking_path(@booking)
    assert_response :not_found
    post client_booking_hold_path(@booking)
    assert_response :not_found
    get departure_bookings_path(@alpha.departure)
    assert_response :not_found
  end
end
