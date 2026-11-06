require "application_system_test_case"

# Slice 1 step 3 screens S-12 to S-18, S-33 and S-34 at desktop width and 375px.
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
    rate_line = cruise.rate_lines.first
    paths = [
      departure_arrangements_path(departure),
      departure_arrangement_path(departure, cruise),
      edit_departure_arrangement_path(departure, cruise),
      new_departure_arrangement_path(departure),
      departure_arrangement_confirmation_path(departure, cruise),
      new_departure_arrangement_rate_line_path(departure, cruise),
      edit_departure_arrangement_rate_line_path(departure, cruise, rate_line),
      departure_arrangement_path(departure, hotel),
      departure_inventory_path(departure),
      departure_arrangement_group_path(departure, hotel, hotel.inventory_groups.find_by!(label: "Nov 5 Harbor Double")),
      departure_arrangement_group_path(departure, @alpha.arrangements.fetch(:excursion), @alpha.arrangements.fetch(:excursion).inventory_groups.sole),
      new_departure_arrangement_deadline_path(departure, cruise),
      edit_departure_arrangement_deadline_path(departure, cruise, cruise.deadlines.first),
      tasks_path,
      task_path(cruise.deadlines.first.task),
      departure_tasks_path(departure)
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

  test "at 375px the rate table stacks each rate with its labels" do
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    resize_window(375)
    visit departure_arrangement_path(@alpha.departure, @alpha.arrangements.fetch(:cruise))
    wait_for_turbo
    within("#rate-table") do
      row = find("tbody tr", text: "S01", match: :first)
      assert_includes row.text, "Base fare"
      assert_includes row.text, "Commission"
    end
  end
end
