require "application_system_test_case"

# Slice 1 step 2 screens S-06 to S-09 at desktop width and 375px.
class DepartureScreensTest < ApplicationSystemTestCase
  setup do
    @scenario = M1DirectoryScenario.empty
    @admin = @scenario.actor
    @staff = @scenario.baseline_staff
  end

  teardown do
    M2DepartureScenario.cleanup!(@scenario.agency)
  end

  test "a Draft saved with fields missing is completed, marked Ready to sell, given Proceed and a team" do
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    visit new_departure_path
    wait_for_turbo
    fill_in "Name", with: "Coastal Week"
    select "No time zone", from: "Time zone"
    fill_in "Operating currency", with: ""
    click_button "Save departure"

    assert_text "Departure saved."
    assert_text "Not on sale"
    within("#details") do
      assert_text "Draft"
      assert_text "Undecided"
    end
    within("#ready-to-sell") { assert_text "Enter a start date and an end date." }

    click_link_and_expect "Edit departure", heading: "Edit departure", css: ".dd-page-actions a"
    fill_in_html_date "Start date", "2027-05-01"
    fill_in_html_date "End date", "2027-05-08"
    select "America/New_York", from: "Time zone"
    fill_in "Operating currency", with: "USD"
    fill_in "Client hold duration (days)", with: "3"
    click_button "Save departure"
    assert_text "Departure updated."
    within("#details") do
      assert_text "3 days"
      assert_text "(this departure)"
    end

    click_link_and_expect "Mark Ready to sell", heading: "Mark Ready to sell", css: ".dd-page-actions a"
    click_button "Mark Ready to sell"
    assert_text "On sale"

    within("#decision") do
      fill_in "Note (optional)", with: "Bookings look healthy"
      click_button "Record Proceed"
    end
    within("#decision") { assert_text "Bookings look healthy" }

    within("#team") do
      select @staff.display_name, from: "Add a team member"
      click_button "Add to team"
    end
    within("#team tr", text: @staff.display_name) { click_button "Make default owner" }
    within("#team tr", text: @staff.display_name) { assert_text "Default task owner" }

    visit departures_path
    wait_for_turbo
    within("tr", text: "Coastal Week") do
      assert_text "On sale"
      assert_text @staff.display_name
    end
    select "On sale", from: "Status"
    click_button "Apply"
    assert_text "Coastal Week"
  end

  test "S-06 to S-09 reflow at 375px without page overflow" do
    departure = CreateDeparture.new(agency: @scenario.agency, actor: @admin, attributes: { name: "Narrow Week" }).call.record
    sign_in_from_browser(@admin, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      [ departures_path, departure_path(departure), edit_departure_path(departure), new_departure_path,
        departure_ready_to_sell_path(departure) ].each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_selector "nav[aria-label='Breadcrumb']"
        assert_no_page_overflow
      end
    end
  end
end
