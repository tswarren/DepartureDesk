require "application_system_test_case"

# Slice 1 step 6a screens S-22 to S-24, at desktop width and 375px.
class TravelerTripScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :trips)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "S-22 to S-24 reflow at 375px without page overflow" do
    trip = @alpha.trips.fetch("BK-104")
    client = trip.client
    traveler = client.travelers.find_by!(given_names: "Milo")
    paths = [
      client_person_path(client.client_person),
      new_client_path(source: "individual"),
      new_traveler_path(client_id: client.id),
      traveler_path(traveler),
      edit_traveler_path(traveler),
      new_traveler_link_path(client_id: client.id, q: "Rivera"),
      client_trip_path(trip),
      new_client_trip_path(client_id: client.id),
      edit_client_trip_path(trip)
    ]

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      paths.each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_no_page_overflow
      end
    end
  end

  test "staff add a traveler from the client profile and see them listed" do
    client = @alpha.trips.fetch("BK-101").client
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    visit client_person_path(client.client_person)
    within("#travelers") { click_on "Add traveler" }
    fill_in "Given names", with: "June"
    fill_in "Surname", with: "Rowan"
    fill_in_html_date "Date of birth", "2020-05-04"
    select "Family member", from: "Relationship to Nadia Rowan"
    click_on "Save traveler"
    assert_text "Traveler saved."
    within("#travelers") { assert_selector "th", text: "June Rowan" }
  end
end
