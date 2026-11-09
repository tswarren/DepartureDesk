require "test_helper"

# UX consolidation batch 2: the Departure's tabs in the order the work runs,
# one Money tab with client and supplier money kept apart (audit A1,
# decision 2), and one trail to a trip and its bookings (A5).
class DepartureMoneyTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), bookings: :paid)
    set_clock Time.utc(2027, 2, 3, 15)
    @departure = @alpha.departure
    sign_in_as agency_users(:harbor_admin)
  end

  test "the tabs follow the work, with one Money tab" do
    get departure_path(@departure)

    tabs = css_select("nav[aria-label='Departure sections'] a").map { |link| link.text.strip }
    assert_equal [ "Overview", "Suppliers", "Inventory", "Package", "Client terms", "Bookings", "Money", "Tasks" ], tabs
  end

  test "the Money tab shows client money by trip, then supplier money" do
    get departure_money_path(@departure)

    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Money"
    trip = @alpha.bookings.fetch("BK-104").client_trip
    assert_select "#client-money tr", text: /#{trip.trip_reference}.*Sofia Bennett.*\$12,570\.00.*\$500\.00.*\$12,070\.00/m
    assert_select "#exposure"
    assert_select "#supplier-payments"
  end

  test "the old Supplier money address leads to the Money tab" do
    get "/departures/#{@departure.id}/supplier_money?view=booking"

    assert_redirected_to "/departures/#{@departure.id}/money?view=booking"
  end

  test "a trip and its booking are reached through the Departure's bookings" do
    booking = @alpha.bookings.fetch("BK-104")
    trail = [ "Departures", @departure.display_reference, "Bookings", booking.client_trip.trip_reference ]

    get client_trip_path(booking.client_trip)
    assert_equal trail, css_select("nav[aria-label=Breadcrumb] a, nav[aria-label=Breadcrumb] [aria-current]").map { |crumb| crumb.text.strip }
    assert_select "nav[aria-label='Primary navigation'] a[aria-current=page]", text: "Departures"

    get client_booking_path(booking)
    assert_equal trail + [ booking.booking_reference ], css_select("nav[aria-label=Breadcrumb] a, nav[aria-label=Breadcrumb] [aria-current]").map { |crumb| crumb.text.strip }
  end
end
