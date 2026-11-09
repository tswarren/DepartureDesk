require "application_system_test_case"

# Demonstration case D9 (first-slice charter). Rules: CMN-06, CMN-29, CMN-55; D-96 (3).
class DemonstrationD9Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    @alpha = @scenario.alpha
    set_clock Time.utc(2027, 2, 3, 15)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D9: payments by route reach the agency or the supplier" do
    trips = @alpha.bookings.transform_values(&:client_trip)
    receivable = -> { trips.values.sum { |trip| TripMoney.new(trip.reload).receivable_minor_units } }
    before = receivable.call

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ [ "BK-101", "2027-01-12", "Check", "The agency", "Check 1047" ],
      [ "BK-104", "2027-01-19", "Bank transfer", "The agency", "Transfer 0119" ],
      [ "BK-105", "2027-02-02", "Card", "A supplier, directly", nil ] ].each do |label, date, method, route, reference|
      visit new_client_trip_payment_path(trips.fetch(label))
      fill_in_html_date "Date paid", date
      fill_in "Amount (USD)", with: "500"
      select method, from: "How it was paid"
      choose route
      if reference
        fill_in "Reference (optional)", with: reference
      else
        select "Alpha Cruises", from: "Supplier"
        fill_in "Supplier's reference (optional)", with: "8812457"
      end
      deposit = @alpha.bookings.fetch(label).client_charge.installments.first
      assert_field "Apply to #{@alpha.bookings.fetch(label).booking_reference} #{deposit.description}", with: "500.00"
      click_button "Record payment"
      assert_text(reference ? "receipt RCP-" : "recorded.")
    end

    agency_payments = trips.values.flat_map { |trip| trip.client_payments.reload.to_a }
    assert_equal 100_000, Receipt.where(client_payment: agency_payments).sum(:amount_minor_units), "agency receipts total $1,000"
    assert_equal 150_000, before - receivable.call, "the receivable drops by $1,500"
    alpha_payment = trips.fetch("BK-105").client_payments.sole
    assert alpha_payment.supplier_route?
    assert_nil alpha_payment.receipt, "the Alpha payment has no receipt"

    visit departure_money_path(@alpha.departure)
    within("#client-money") do
      assert_selector "div", text: /Paid to the agency\s*\$1,000\.00/
      assert_selector "div", text: /Paid to suppliers\s*\$500\.00/
      assert_selector "div", text: /Held by suppliers for the agency\s*\$500\.00/
    end
    visit client_trip_path(trips.fetch("BK-105"), anchor: "money")
    within("#money") { assert_text "No receipt: paid to a supplier" }
  end
end
