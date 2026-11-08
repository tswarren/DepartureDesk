require "application_system_test_case"

# Demonstration case D6 (first-slice charter). Rules: INV-39, BKG-16.
class DemonstrationD6Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @scenario = AlphaScenario.load!(bookings: :held)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D6: excursion choices use positions" do
    tour = @alpha.arrangements.fetch(:excursion).inventory_groups.sole
    participants = @alpha.bookings.values.flat_map do |booking|
      booking.choice_selections.select { |selection| selection.inventory_group == tour }.flat_map(&:occupants)
    end
    assert_equal 9, participants.size
    assert_equal 7, tour.unit_shells.sole.positions_used
    assert_equal 3, tour.unit_shells.sole.positions_left
    free = participants.select { |occupant| tour.capacity_rules.any? { |rule| rule.traveler_type_id == occupant.booking_traveler.traveler_type_id && !rule.uses_capacity? } }
    assert_equal %w[Luca Milo], free.map { |occupant| occupant.booking_traveler.traveler.given_names }.sort,
      "children 0–4 take part without a position"

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_inventory_path(@alpha.departure)
    within("section", text: "Private Miami tour") do
      assert_text "9 participants · 7 of 10 positions used · 3 left"
      assert_text "Taking part without a position:"
      assert_text "Milo Bennett"
      assert_text "Luca Rivera"
      assert_text "Partly allocated"
    end

    visit client_booking_path(@alpha.bookings.fetch("BK-105"), step: "rooms")
    within("#choices") do
      assert_text "Luca Rivera · takes part without a position"
      assert_no_text "Elena Rivera · takes part"
    end
  end
end
