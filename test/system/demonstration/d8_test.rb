require "application_system_test_case"

# Demonstration case D8 (first-slice charter). Rules: INV-33 to INV-37.
class DemonstrationD8Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    @alpha = @scenario.alpha
    set_clock Time.utc(2027, 2, 3, 15)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D8: on-request hotel nights await the supplier, and the hotel's acceptance is recorded" do
    booking = @alpha.bookings.fetch("BK-104")
    hotel = @alpha.arrangements.fetch(:hotel)
    assert booking.status_confirmed?
    before = [ booking.price_lines.map(&:amount_minor_units).sort, booking.client_charge.lines.map(&:amount_minor_units).sort, booking.inventory_allocations.map(&:state).sort ]

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit client_booking_path(booking, step: "rooms")
    within("#supplier-requests tbody") do
      assert_selector "tr", text: /Extension nights \d+: Nov 2 Harbor Double.*None; on request.*Request from the supplier/m
      assert_selector "tr", text: /Extension nights \d+: Nov 3 Harbor Double.*None; on request.*Request from the supplier/m
      assert_selector "tr", text: /Nov 4 Harbor Double.*Reserved.*In the group block/m
    end
    nights = booking.choice_selections.select { |selection| selection.inventory_group.label.in?([ "Nov 2 Harbor Double", "Nov 3 Harbor Double" ]) }
    within("#request-#{hotel.id}") do
      nights.each { |selection| assert_checked_field selection.label }
      click_button "Start the request"
    end
    assert_text "Supplier request started."
    within("#supplier-requests tbody") do
      assert_selector "tr", text: /Nov 2 Harbor Double.*Awaiting supplier/m
      assert_selector "tr", text: /Nov 3 Harbor Double.*Awaiting supplier/m
    end
    visit departure_bookings_path(@alpha.departure)
    assert_selector "tr", text: /#{booking.booking_reference}.*2 awaiting supplier/m

    reservation = booking.supplier_reservations.sole
    [ client_booking_path(booking, step: "rooms"), departure_arrangement_reservations_path(@alpha.departure, hotel),
      new_departure_arrangement_supplier_reservation_acceptance_path(@alpha.departure, hotel, reservation) ].each do |path|
      visit path
      [ 1400, 375 ].each do |width|
        resize_window(width)
        assert_no_page_overflow
      end
    end
    resize_window(1400)

    visit departure_arrangement_reservations_path(@alpha.departure, hotel)
    within("#supplier-reservations") do
      assert_text "Awaiting supplier"
      click_link "Record acceptance"
    end
    fill_in "Supplier reference", with: "SHH-24117"
    click_button "Record acceptance"
    assert_text "The supplier's acceptance is recorded."
    within("#supplier-reservations") { assert_text "ref SHH-24117" }

    visit client_booking_path(booking, step: "rooms")
    within("#supplier-requests tbody") do
      assert_selector "tr", text: /Nov 2 Harbor Double.*Confirmed by the supplier.*Ref SHH-24117/m
      assert_selector "tr", text: /Nov 3 Harbor Double.*Confirmed by the supplier.*Ref SHH-24117/m
    end
    booking.reload
    assert_equal before, [ booking.price_lines.map(&:amount_minor_units).sort, booking.client_charge.lines.map(&:amount_minor_units).sort, booking.inventory_allocations.map(&:state).sort ],
      "the supplier's acceptance changes no price, charge or allocation (INV-35)"
  end

  test "D8 (Slice 1b): a decline is flagged, acceptance is kept and nothing cancels" do
    skip "Pending: Slice 1b"
  end
end
