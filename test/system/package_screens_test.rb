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
    find("summary", text: "Set one price here instead").click
    select "Child", from: "Traveler type"
    fill_in "Amount (USD)", with: "75"
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

  test "a choice preset fills in its rules, and the extra nights page reflows" do
    departure = @alpha.departure
    offering = @alpha.offering
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit new_departure_offering_choice_path(departure, offering)
    choose "Per-person add-on"
    assert_select "Role", selected: "Add-on"
    assert_select "Made", selected: "Per traveler"
    choose "Cabin"
    assert_field "Name", with: "Cabin"
    assert_select "Pattern", selected: "Required, choose one"

    visit new_departure_offering_night_options_path(departure, offering)
    assert_selector "h1", text: "Add extra nights"
    [ 1400, 375 ].each do |width|
      resize_window(width)
      assert_no_page_overflow
    end
  end

  test "the payment schedule and tier forms show only the fields each choice uses" do
    departure = @alpha.departure
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit new_departure_client_schedule_line_path(departure)
    select "Fixed amount per unit", from: "Amount"
    assert_field "For each"
    assert_no_field "Percentage"
    select "Percentage of the booking total", from: "Amount"
    assert_field "Percentage"
    assert_no_field "For each"
    select "On a date", from: "Due"
    assert_field "Due date"
    assert_no_field "Days before departure"

    visit new_departure_client_cancellation_tier_path(departure)
    select "Fixed amount per traveler", from: "Charge"
    assert_field "Amount (USD)"
    assert_no_field "Percentage"
    assert_no_field "For each"
  end

  test "the schedule line and tier forms say the line in a sentence as it is filled in (C2)" do
    departure = @alpha.departure
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit new_departure_client_schedule_line_path(departure)
    wait_for_turbo
    assert_text "Choose how much and when it is due."
    select "Fixed amount per traveler", from: "Amount"
    fill_in "Fixed amount (USD)", with: "250"
    select "Days before departure", from: "Due"
    fill_in "Days before departure", with: "90"
    assert_text "$250.00 for each traveler, due 90 days before departure: Aug 8, 2027. It doesn't count as acceptance."

    visit new_administration_cancellation_tier_path
    wait_for_turbo
    fill_in "From how many days before departure", with: "60"
    select "Percentage of the service's charge", from: "Charge"
    fill_in "Percentage", with: "50"
    assert_text "Cancelling 60 days or more before departure costs 50% of the service's charge, until the next tier closer to departure."
  end
end
