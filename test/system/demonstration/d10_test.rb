require "application_system_test_case"

# Demonstration case D10 (first-slice charter). Rules: SMN-03, SMN-19; D-92, D-96 (3).
class DemonstrationD10Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    @alpha = @scenario.alpha
    set_clock Time.utc(2027, 2, 3, 15)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D10: staff pay Alpha the amounts due" do
    cruise = @alpha.arrangements.fetch(:cruise)
    amounts = -> { cruise.amounts_due.reload.includes(:payment_applications) }
    assert_equal 295_000, amounts.call.sum(&:amount_minor_units), "$1,600 and $450 for each of the three confirmed cabins"
    cost = CostLine.where(supplier_arrangement: cruise).order(:id).pluck(:id, :amount_minor_units)
    capacity = [ CapacityEvent.where(agency: @scenario.agency).count, InventoryAllocation.where(agency: @scenario.agency).pluck(:id, :state).sort ]

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_supplier_money_path(@alpha.departure)
    within("#supplier-payments") { click_link "Record a payment to Alpha Cruises" }
    fill_in "Amount (USD)", with: "2,950"
    fill_in "Bank or card reference (optional)", with: "Wire 0203"
    fill_in_html_date "Date paid", "2027-02-03"
    assert_select "Paid to (optional)", selected: "Alpha Cruises group sales (USD)"
    click_button "Record payment"
    assert_text(/SPY-\d{4} recorded\./)

    assert(amounts.call.all? { |amount| amount.paid_status == "paid" }, "amounts due are settled")
    assert_equal cost, CostLine.where(supplier_arrangement: cruise).order(:id).pluck(:id, :amount_minor_units), "the deposit is never added to cost (SMN-03)"
    assert_equal capacity, [ CapacityEvent.where(agency: @scenario.agency).count, InventoryAllocation.where(agency: @scenario.agency).pluck(:id, :state).sort ],
      "no payment changes capacity (D-92)"
    within("#amounts-due") { assert_no_text "Unpaid" }
    within("#supplier-payments") { assert_text "Still open\n$0.00" }
  end
end
