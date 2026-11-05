require "application_system_test_case"

class DeparturesTest < ApplicationSystemTestCase
  test "an administrator creates a departure, marks it Ready to sell, and returns it to Draft" do
    sign_in_from_browser(agency_users(:harbor_admin))

    open_departures
    click_link "New Departure"
    assert_selector "h1.dd-page-title", exact_text: "New departure"

    fill_in "Name", with: "Harbor Reunion"
    fill_in_html_date "Start date", "2026-12-01"
    fill_in_html_date "End date", "2026-12-08"
    fill_in "Operating currency", with: "USD"
    click_button "Save departure"

    assert_text "Departure saved."
    assert_text "Harbor Reunion"
    assert_text "Not on sale"

    click_link "Mark Ready to sell"
    assert_selector "h1.dd-page-title", exact_text: "Mark Ready to sell"
    click_button "Mark Ready to sell"

    assert_text "Departure is Ready to sell."
    assert_text "DEP-0001"
    assert_text "On sale"

    click_link "Return to Draft"
    fill_in "Note (optional)", with: "Hold for a later sailing"
    click_button "Return to Draft"

    assert_text "Departure returned to Draft."
    assert_text "DEP-0001"
    assert_text "Not on sale"
  end

  test "invalid create preserves submitted values in the error summary" do
    sign_in_from_browser(agency_users(:harbor_admin))
    open_departures
    click_link "New Departure"
    select "America/Chicago", from: "Time zone"
    click_button "Save departure"

    assert_selector "#form-error-summary"
    assert_field "Time zone", with: "America/Chicago"
  end

  test "staff without departure management can browse departures without mutation actions" do
    CreateDeparture.new(
      agency: agencies(:harbor),
      actor: agency_users(:harbor_admin),
      attributes: { name: "Viewer Cruise" }
    ).call

    sign_in_from_browser(agency_users(:harbor_baseline_staff))
    open_departures
    assert_text "Viewer Cruise"
    assert_no_text "New Departure"
    click_link "Viewer Cruise"
    assert_text "Not on sale"
    assert_no_text "Edit departure"
    assert_no_text "Activate"
  end

  test "an administrator marks an eligible departure departed, which leaves it read-only" do
    departure = CreateDeparture.new(
      agency: agencies(:harbor),
      actor: agency_users(:harbor_admin),
      attributes: {
        name: "Departed Reunion",
        starts_on: Date.new(2026, 6, 1),
        ends_on: Date.new(2026, 6, 8),
        time_zone: "America/New_York",
        operating_currency: "USD"
      }
    ).call.record
    MarkDepartureReadyToSell.new(
      agency: agencies(:harbor),
      actor: agency_users(:harbor_admin),
      departure:,
      lock_version: departure.lock_version
    ).call

    sign_in_from_browser(agency_users(:harbor_admin))
    visit departure_path(departure)
    click_link "Mark departed"
    assert_selector "h1.dd-page-title", exact_text: "Mark departed"
    click_button "Mark departed"

    assert_text "Departure marked departed."
    assert_text "Departed"

    assert_no_link "Edit departure"
    assert_no_link "Return to Draft"
    assert_no_button "Record Proceed"
  end
end
