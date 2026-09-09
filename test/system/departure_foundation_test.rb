require "application_system_test_case"

class DepartureFoundationTest < ApplicationSystemTestCase
  test "administrator creates a program and departure then starts planning" do
    sign_in_from_browser(users(:one))
    click_primary_nav "Departures", heading: "Departures"

    click_link_and_expect "Travel programs", heading: "Travel programs"
    click_link_and_expect "New travel program", heading: "New travel program"
    fill_in "Name", with: "Smith Family Reunion"
    click_button "Create travel program"
    assert_selector "h1.dd-page-title", text: "Smith Family Reunion"

    # Program pages expose both the sidebar and local subnav "Departures" links.
    click_link_and_expect "Departures", heading: "Departures", css: "nav.dd-subnav a"
    click_link_and_expect "New departure", heading: "New departure"
    fill_in "Name", with: "Smith Family Reunion Cruise"
    fill_in_html_date "Start date", "2027-07-12"
    fill_in_html_date "End date", "2027-07-19"
    click_button "Create departure"

    assert_selector "h1.dd-page-title", text: "Smith Family Reunion Cruise"
    assert_text(/D-\d{6,}/)
    click_button "Start planning"
    assert_text "Planning"
  end
end
