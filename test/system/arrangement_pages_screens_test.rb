require "application_system_test_case"

# S-12, S-16 and S-18 (UX consolidation audit batch 4): the arrangement's
# section tabs, the cost line form's conditional fields and the sentence the
# cost line and capacity change forms write as they are filled in (C2, C3).
class ArrangementPagesScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    @alpha = @scenario.alpha
    @departure = @alpha.departure
    @hotel = @alpha.arrangements.fetch(:hotel)
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "the section tabs move between the arrangement's pages" do
    visit departure_arrangement_path(@departure, @hotel)
    click_link_and_expect "Payments and deadlines", heading: @hotel.supplier.display_name_for_directory,
      path: departure_arrangement_payments_path(@departure, @hotel), css: "nav[aria-label='Arrangement sections'] a"
    assert_selector "#supplier-payments h2", text: "When you pay"
    assert_selector "#deadlines h2", text: "Supplier deadlines"
  end

  test "the cost line form shows the fields its basis uses and says the line in a sentence" do
    visit new_departure_arrangement_cost_line_path(@departure, @hotel)
    wait_for_turbo
    assert_no_field "Inventory group"
    assert_no_field "Percentage"

    fill_in "Description", with: "Late checkout"
    select "Committed", from: "Stage"
    select "Per unit", from: "Basis"
    fill_in "Amount or rate", with: "40"
    fill_in "Quantity", with: "2"
    assert_text "Committed cost of $80.00 for the whole arrangement: $40.00 × 2 per unit."

    select "One inventory group", from: "Covers"
    assert_field "Inventory group"
    select "Percentage of a cost line", from: "Basis"
    assert_no_field "Quantity"
    assert_field "Percentage"
  end

  test "the capacity change form says what the change leaves, and what a release leaves short" do
    group = @hotel.inventory_groups.find_by!(label: "Nov 4 Garden Queen")
    visit departure_arrangement_group_path(@departure, @hotel, group)
    wait_for_turbo
    within("#supply-change") do
      fill_in "increase_quantity", with: "1"
      assert_text "The supplier gives 1 more place from today: 3 places from the supplier, 1 left."
      choose "The supplier took some back"
      fill_in "supplier_release_quantity", with: "1"
      assert_text "That leaves 1 place while bookings hold 2, so 1 short; the bookings affected are flagged."
    end
  end
end
