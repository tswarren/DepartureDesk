require "test_helper"

# S-20: package choice presets, and extra nights as one option per night
# and room type (BKG-14 to BKG-16, BKG-21, INV-13).
class OfferingNightOptionsTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin)
    @departure = @alpha.departure
    @offering = @alpha.offering
    nights = @offering.choices.find_by!(name: "Extension nights")
    nights.options.each { |option| RemoveOfferingOption.new(agency: @agency, actor: @admin, departure: @departure, offering: @offering, option:).call }
    RemoveOfferingChoice.new(agency: @agency, actor: @admin, departure: @departure, offering: @offering, choice: nights.reload).call
  end

  test "the new-choice form offers presets and a way to add extra nights" do
    sign_in_as @admin
    get new_departure_offering_choice_path(@departure, @offering)
    assert_select "input[type=radio][name=kind][value=cabin]"
    assert_select "a[href='#{new_departure_offering_night_options_path(@departure, @offering)}']", text: "Add extra nights"
  end

  test "extra nights become one option per night and room type, priced from the included room" do
    sign_in_as @admin
    get new_departure_offering_night_options_path(@departure, @offering)
    assert_select "input[name='kinds[]'][value='Garden Queen']"
    assert_select "select[name=from] option", text: "Nov 1"
    assert_select "select[name=through] option", text: "Nov 4"
    room = @offering.choices.find_by!(name: "Nov 5 hotel room")

    post departure_offering_night_options_path(@departure, @offering), params: {
      name: "Extension nights", from: "2027-11-02", through: "2027-11-04", kinds: [ "Garden Queen" ], price_from_choice_id: room.id
    }
    assert_redirected_to departure_offerings_path(@departure)
    choice = @offering.choices.reload.find_by!(name: "Extension nights")
    assert_equal %w[add_on per_unit optional_multiple], choice.values_at(:role, :scope, :pattern)
    assert_equal [ "Nov 2 Garden Queen", "Nov 3 Garden Queen", "Nov 4 Garden Queen" ], choice.options.map(&:label)
    nov2 = choice.options.first
    assert_equal({ "guest_1" => 19_000, "any" => 0 }, nov2.prices.to_h { |price| [ price.occupancy_position, price.amount_minor_units ] })
    assert_equal "Nov 2 Garden Queen", nov2.inventory_group.label
  end

  test "no room type chosen adds nothing" do
    sign_in_as @admin
    assert_no_difference -> { OfferingChoice.count } do
      post departure_offering_night_options_path(@departure, @offering), params: { name: "Extension nights", from: "2027-11-01", through: "2027-11-04" }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /at least one night and room type/
  end
end
