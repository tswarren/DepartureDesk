require "test_helper"

# S-24 and S-26 (UX consolidation audit batch 5): the booking's read-only
# Summary, where a confirmed booking opens (A6, decision 7); Price and
# installments apart from Hold space (B2); Money once confirmed (decision 4);
# the trip page as the trip's summary; and a Print button on both (decision 8).
class BookingSummaryTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :paid)
    set_clock Time.utc(2027, 2, 3, 15)
    @booking = @alpha.bookings.fetch("BK-104")
    @trip = @booking.client_trip
  end

  test "a confirmed booking opens on its Summary, with each section linking to its step" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get client_booking_path(@booking)
    steps = css_select("nav[aria-label='Booking steps'] a strong").map { |step| step.text.strip }
    assert_equal [ "Summary", "1 · Travelers", "2 · Rooms and options", "3 · Price and installments", "4 · Hold space", "5 · Accept and confirm", "Money" ], steps
    assert_select "nav[aria-label='Booking steps'] a[aria-current=step]", text: /Summary/
    assert_select "nav[aria-label='Booking steps'] a", text: /Money\s+\$[\d,.]+ still due/
    assert_select "button", text: "Print"

    assert_select "#summary-travelers th[scope=row]", text: "Milo Bennett"
    assert_select "#summary-travelers td", text: /Cabin 1: S01.*, 4th guest/
    assert_select "#summary-travelers a[href='#{client_booking_path(@booking, step: "travelers")}']"
    assert_select "#summary-services tfoot td", text: /\$12,570\.00/
    assert_select "#summary-services td", text: /Space\s+Reserved/
    assert_select "#summary-services a[href='#{client_booking_path(@booking, step: "rooms")}']"
    assert_select "#summary-acceptance p", text: /Accepted by .*phone, January 19, 2027, at \$12,570\.00 under client terms version 1\./
    assert_select "#summary-money dd", text: "$500.00"
    assert_select "#summary-money li", text: /PAY-\d{5}, \$500\.00 to the deposit · receipt RCP-\d{5}/
    assert_select "#summary-next li", text: /due/
    assert_select "#summary-next a", text: /Record the client's acceptance/, count: 0
  end

  test "a draft opens on its next step, has no Money, and its Summary lists what confirming needs" do
    draft = CreateClientBooking.new(agency: @agency, actor: @admin, trip: @trip).call.record
    sign_in_as @admin
    get client_booking_path(draft)
    assert_select "nav[aria-label='Booking steps'] a[aria-current=step]", text: /1 · Travelers/
    assert_select "nav[aria-label='Booking steps'] a", text: /Money/, count: 0
    get client_booking_path(draft, step: "money")
    assert_select "nav[aria-label='Booking steps'] a[aria-current=step]", text: /1 · Travelers/

    get client_booking_path(draft, step: "summary")
    assert_select "#summary-travelers", text: /No travelers yet/
    assert_select "#summary-next a[href='#{client_booking_path(draft, step: "travelers", anchor: "travelers")}']", text: "Add the travelers."
    assert_select "#summary-money", text: /No charge yet/
  end

  test "Price and installments and Hold space are separate steps" do
    sign_in_as @admin
    get client_booking_path(@booking, step: "price")
    assert_select "#prices"
    assert_select "#installments"
    assert_select "#hold", count: 0
    get client_booking_path(@booking, step: "hold")
    assert_select "#hold h2", text: "Space"
    assert_select "#prices", count: 0
  end

  test "Money shows the booking's balance, installments and each payment applied to it" do
    sign_in_as @admin
    get client_booking_path(@booking, step: "money")
    assert_select "#booking-balance dd", text: "$500.00"
    assert_select "#booking-balance p", text: /Next due: .* for the balance, on/
    assert_select "#booking-installments th[scope=row]", text: "Deposit"
    assert_select "#booking-payments li", text: /PAY-\d{5} · January 19, 2027 · Sofia Bennett · Bank transfer to the agency\s+\$500\.00 applied to Deposit · reference Transfer 0119/
    assert_select "#booking-payments a", text: /Receipt RCP-\d{5}/
  end

  test "the trip page sums up each booking with its travelers, what's next and the money" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get client_trip_path(@trip)
    assert_select "button", text: "Print"
    within_booking = css_select("#booking-#{@booking.id}").first
    assert_includes within_booking.text, "Confirmed"
    assert_includes within_booking.text, "Space reserved"
    assert_includes within_booking.text, "Accepted January 19, 2027"
    assert_includes within_booking.text, "still due"
    assert_select "#booking-#{@booking.id} ul[aria-label='Travelers on #{@booking.booking_reference}'] li", count: 4
    assert_select "#booking-#{@booking.id} ul[aria-label='Travelers on #{@booking.booking_reference}'] li", text: /Milo Bennett/
    assert_select "#next li", text: /Balance of \$[\d,.]+ due .* \(#{@booking.booking_reference}\)\./
    assert_select "#money dd.dd-cell-subtext", text: /Next: /
  end

  test "another agency's booking Summary is not found" do
    sign_in_as agency_users(:cove_admin)
    get client_booking_path(@booking, step: "summary")
    assert_response :not_found
  end
end
