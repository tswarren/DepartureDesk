require "application_system_test_case"

# S-06 Departures and S-07 the Departure overview with the Alpha bookings
# (UX consolidation audit batch 3), at desktop width and 375px.
class DepartureOverviewScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    @departure = @scenario.alpha.departure
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "the overview's summary links to each tab, and both pages reflow at 375px" do
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_path(@departure)
    wait_for_turbo
    within("#summary-bookings") { assert_text "10 travelers" }
    within("#summary-space") { assert_text "7 of 8 left" }
    within("#summary-client-money") { assert_text "Still due from clients" }
    within("#summary-supplier-money") { assert_text "Owed to suppliers now" }
    click_link_and_expect "All tasks", heading: "Alpha Omega", path: departure_tasks_path(@departure), css: "#summary-tasks a"

    [ 1400, 375 ].each do |width|
      resize_window(width)
      [ departures_path, departure_path(@departure) ].each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_no_page_overflow
      end
    end
  end
end
