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
      edit_departure_offering_choice_prices_path(departure, offering, cabin),
      edit_departure_offering_choice_prices_path(departure, offering, offering.choices.find_by!(name: "Private Miami tour")),
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
    assert_selector "th[scope=col]", text: /\Achild\z/i
    assert_selector "tr", text: /Private Miami tour, Nov 5.*Child\s*\$75/m
  end

  test "staff set a choice's client prices in a grid and see them on the package page" do
    departure = @alpha.departure
    offering = @alpha.offering
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_offerings_path(departure)
    find("a[aria-label='Edit Cabin prices']").click
    assert_selector "h1", text: "Cabin"
    assert_field "V01, 1st and 2nd guest: price", with: "3385"
    assert_text "Net supplier cost"

    select "Child 0–4", from: "Traveler type"
    click_on "Add a column"
    assert_selector "th", text: /3rd and 4th guest, Child 0–4/i
    fill_in "V01, 1st and 2nd guest: price", with: "3,450"
    fill_in "V01, 3rd and 4th guest, Child 0–4: price", with: "0"
    click_on "Save prices"
    assert_text "Cabin prices saved."
    within("table", text: "V01") do
      assert_selector "tr", text: /V01.*\$3,450.*\$1,285.*\$0/m
    end
    option = offering.choices.find_by!(name: "Cabin").options.find_by!(label: "V01")
    assert_equal 345_000, option.prices.find_by!(occupancy_position: "guest_2", traveler_type: nil).amount_minor_units

    find("a[aria-label='Edit Cabin prices']").click
    find("a[aria-label='Price 3rd and 4th guest one guest at a time']").click
    fill_in "S01, 4th guest: price", with: "400"
    click_on "Save prices"
    assert_text "Cabin prices saved."
    assert_selector "tr", text: /S01.*\$535.*\$400/m
  end
end
