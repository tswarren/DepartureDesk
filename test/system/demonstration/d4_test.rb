require "application_system_test_case"

# Demonstration case D4 (first-slice charter, as amended by D-92 and D-94).
# Rules: BKG-25, BKG-45, INV-38, SUP-35, SMN-11, SMN-32.
class DemonstrationD4Test < ApplicationSystemTestCase
  setup do
    # The fixture confirms each booking on its roster date, so it loads before the first.
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    set_clock Time.utc(2027, 2, 3, 15)
    @alpha = @scenario.alpha
    @cruise = @alpha.arrangements.fetch(:cruise)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D4: confirmed cabins and cruise subtotals" do
    bookings = @alpha.bookings.values
    assert bookings.all?(&:status_confirmed?)
    cabin_charges = bookings.to_h do |booking|
      [ booking.client_trip.client.source.display_name, booking.client_charge.lines.select { |line| line.description.start_with?("Cabin") }.sum(&:amount_minor_units) ]
    end
    assert_equal({ "Nadia Rowan" => 805_500, "Sofia Bennett" => 1_124_000, "Mateo Rivera" => 710_500 }, cabin_charges)
    assert_equal 2_640_000, cabin_charges.values.sum, "cruise subtotals total $26,400"

    left = @cruise.inventory_groups.to_h { |group| [ group.label, group.unit_shells.count { |shell| shell.status == "available" } ] }
    assert_equal({ "V01" => 7, "O01" => 7, "I01" => 8, "S01" => 7 }, left)

    bookings.each do |booking|
      cabin = booking.choice_selections.find { |selection| selection.option.choice.name == "Cabin" }
      guests = cabin.occupants.select(&:position).sort_by(&:position).map { |occupant| occupant.booking_traveler.traveler_type }
      proposal = ProposeBookingSupplierCost.new(group: cabin.inventory_group, guests:).call
      assert_equal [ proposal.gross ], booking.cost_lines.map(&:amount_minor_units), "#{booking.booking_reference} cost from the rate table"
      assert_equal [ proposal.commission ], booking.expected_commissions.map(&:amount_minor_units), "#{booking.booking_reference} commission from the rate table"
      shell = booking.inventory_allocations.find { |allocation| allocation.choice_selection_id == cabin.id }.unit_shell
      amount = AmountDue.find_by!(supplier_arrangement: @cruise, unit_shell: shell)
      assert_equal [ 45_000, booking.confirmed_at.in_time_zone(AlphaFixture::TIME_ZONE).to_date ], [ amount.amount_minor_units, amount.due_on ], "$450 for its cabin"
    end
    assert_equal 3, AmountDue.where(supplier_arrangement: @cruise).where.not(unit_shell_id: nil).count, "no deposit for unbooked cabins before Mar 1"

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_bookings_path(@alpha.departure)
    within("tbody") { assert_selector "tr", text: "Confirmed", count: 3 }
    visit departure_inventory_path(@alpha.departure)
    within("section", text: "V01") { assert_text "7 available · 1 fully allocated" }
  end
end
