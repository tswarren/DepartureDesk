require "application_system_test_case"

class DeparturesTest < ApplicationSystemTestCase
  test "an administrator creates, activates, and returns a departure to draft" do
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
    assert_text "Draft"

    click_link "Activate"
    assert_selector "h1.dd-page-title", exact_text: "Activate departure"
    click_button "Activate departure"

    assert_text "Departure activated."
    assert_text "D-000001"
    assert_text "Active"

    click_link "Return to draft"
    fill_in "Reason", with: "Hold for a later sailing"
    click_button "Return to draft"

    assert_text "Departure returned to draft."
    assert_text "D-000001"
    assert_text "Draft"
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

  test "viewer can browse departures without mutation actions" do
    CreateDeparture.new(
      agency: agencies(:harbor),
      actor: agency_users(:harbor_admin),
      attributes: { name: "Viewer Cruise" }
    ).call

    sign_in_from_browser(agency_users(:harbor_viewer))
    open_departures
    assert_text "Viewer Cruise"
    assert_no_text "New Departure"
    click_link "Viewer Cruise"
    assert_text "Draft"
    assert_no_text "Edit departure"
    assert_no_text "Activate"
  end
end
