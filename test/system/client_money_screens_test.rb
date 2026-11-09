require "application_system_test_case"

# Step 8 screens S-28 to S-31, the reversal forms and receipts, at desktop width and 375px.
class ClientMoneyScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :paid)
    @alpha = @scenario.alpha
    set_clock Time.utc(2027, 2, 3, 15)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "the money screens reflow at 375px, and the payment form splits the amount oldest first" do
    trip = @alpha.bookings.fetch("BK-101").client_trip
    payment = trip.client_payments.sole
    paths = [ client_trip_path(trip), new_client_trip_payment_path(trip), new_client_trip_payment_reversal_path(trip, payment), receipt_path(payment.receipt),
              client_booking_path(@alpha.bookings.fetch("BK-101"), step: "price"), departure_bookings_path(@alpha.departure),
              departure_money_path(@alpha.departure), client_booking_path(@alpha.bookings.fetch("BK-101"), step: "confirm"),
              new_departure_supplier_payment_path(@alpha.departure, supplier_id: @alpha.arrangements.fetch(:cruise).supplier_id),
              new_departure_supplier_payment_reversal_path(@alpha.departure, @alpha.departure.supplier_payments.sole) ]
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      paths.each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_no_page_overflow
      end
    end
    resize_window(1400)

    visit new_client_trip_payment_path(trip)
    balance = @alpha.bookings.fetch("BK-101").client_charge.installments.second
    fill_in "Amount (USD)", with: "1,200"
    assert_field "Apply to #{@alpha.bookings.fetch("BK-101").booking_reference} #{balance.description}", with: "1200.00"
    assert_no_field "Supplier"
    choose "A supplier, directly"
    assert_field "Supplier"
  end
end
