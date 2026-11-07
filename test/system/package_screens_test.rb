require "application_system_test_case"

# Slice 1 step 5 screens S-20, S-21 and the Administration client terms page, at desktop width and 375px.
class PackageScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @scenario = AlphaScenario.load!
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "S-20, S-21 and the client terms defaults reflow at 375px without page overflow" do
    departure = @alpha.departure
    offering = @alpha.offering
    cabin = offering.choices.find_by!(name: "Cabin")
    terms = @alpha.client_terms
    tier = @scenario.agency.agency_cancellation_tiers.first
    paths = [
      departure_offerings_path(departure),
      new_departure_offering_path(departure),
      edit_departure_offering_path(departure, offering),
      new_departure_offering_choice_path(departure, offering),
      edit_departure_offering_choice_path(departure, offering, cabin),
      new_departure_offering_choice_option_path(departure, offering, cabin),
      edit_departure_offering_choice_option_path(departure, offering, cabin, cabin.options.first),
      departure_client_terms_path(departure),
      new_departure_client_cancellation_tier_path(departure),
      edit_departure_client_cancellation_tier_path(departure, terms.own_cancellation_tiers.first),
      new_departure_client_schedule_line_path(departure),
      edit_departure_client_schedule_line_path(departure, terms.schedule_lines.first),
      administration_client_terms_defaults_path,
      new_administration_cancellation_tier_path,
      edit_administration_cancellation_tier_path(tier)
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

  test "staff set a price on the option page and see it on the package" do
    offering = @alpha.offering
    tour = offering.choices.find_by!(name: "Private Miami tour")
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit edit_departure_offering_choice_option_path(@alpha.departure, offering, tour, tour.options.sole)
    wait_for_turbo
    select "Child", from: "Traveler type"
    fill_in "Price", with: "75"
    click_button_and_expect "Save price", text: "Price saved."
    visit departure_offerings_path(@alpha.departure)
    assert_text "Any position, Child $75.00"
  end
end
