require "application_system_test_case"

# Slice 1 steps 3 and 4 screens S-12 to S-18, S-33, S-34 and the Departure's Supplier money tab, at desktop width and 375px.
class ArrangementScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @scenario = AlphaScenario.load!(confirm_cruise: false)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "S-12 to S-18, S-33 and S-34 reflow at 375px without page overflow" do
    departure = @alpha.departure
    cruise = @alpha.arrangements.fetch(:cruise)
    hotel = @alpha.arrangements.fetch(:hotel)
    paths = [
      departure_arrangements_path(departure),
      departure_arrangement_path(departure, cruise),
      edit_departure_arrangement_path(departure, cruise),
      new_departure_arrangement_path(departure),
      departure_arrangement_confirmation_path(departure, cruise),
      edit_departure_arrangement_rates_path(departure, cruise),
      departure_arrangement_path(departure, hotel),
      departure_inventory_path(departure),
      departure_arrangement_group_path(departure, hotel, hotel.inventory_groups.find_by!(label: "Nov 5 Harbor Double")),
      departure_arrangement_group_path(departure, @alpha.arrangements.fetch(:excursion), @alpha.arrangements.fetch(:excursion).inventory_groups.sole),
      new_departure_arrangement_deadline_path(departure, cruise),
      edit_departure_arrangement_deadline_path(departure, cruise, cruise.deadlines.first),
      tasks_path,
      task_path(cruise.deadlines.first.task),
      departure_tasks_path(departure),
      new_departure_arrangement_cost_line_path(departure, hotel),
      edit_departure_arrangement_cost_line_path(departure, hotel, hotel.cost_lines.first),
      new_departure_arrangement_schedule_line_path(departure, hotel),
      edit_departure_arrangement_schedule_line_path(departure, hotel, hotel.schedule_lines.first),
      new_departure_arrangement_trigger_event_path(departure, hotel),
      new_departure_arrangement_amount_due_path(departure, hotel),
      departure_supplier_money_path(departure),
      task_path(@alpha.arrangements.fetch(:excursion).deadlines.find_by!(deadline_type: "final_count").task)
    ]

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      paths.each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_selector "nav[aria-label='Breadcrumb']"
        assert_no_page_overflow
      end
    end
  end

  test "at 375px the rate grid stacks each group with its bands" do
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    resize_window(375)
    visit departure_arrangement_path(@alpha.departure, @alpha.arrangements.fetch(:cruise))
    wait_for_turbo
    within("#rate-table") do
      row = find("tbody tr", text: "S01", match: :first)
      assert_includes row.text, "1st and 2nd guest"
      assert_includes row.text, "Single"
    end
  end

  test "the rate page shows only the commission fields the method needs, and saves the grid" do
    cruise = @alpha.arrangements.fetch(:cruise)
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit edit_departure_arrangement_rates_path(@alpha.departure, cruise)
    wait_for_turbo
    within("#shared") do
      assert_field "Rate (%)", with: "14"
      assert_no_field "Amount per guest (USD)"
      choose "Dollar amount"
      assert_field "Amount per guest (USD)"
      assert_no_field "Rate (%)"
      choose "Percentage"
      fill_in "Taxes and fees", with: "150"
    end
    first("details.dd-rate-details summary").click
    within(first("details.dd-rate-details")) do
      assert_text "Uses 14% of the commissionable fare, as set for every fare."
      assert_no_field "Rate (%)"
      choose "Dollar amount"
      fill_in "Amount per guest (USD)", with: "400"
    end
    click_button "Save rates"
    assert_text "Supplier rates saved."
    assert cruise.rate_lines.reload.all? { |line| line.taxes_minor_units == 15_000 }
    assert_equal %w[guest_1 guest_2], cruise.rate_lines.select { |line| line.commission_minor_units == 40_000 }.map(&:occupancy_position).sort,
      "one fare's own dollar commission, stored for both guests it covers"
  end
end
