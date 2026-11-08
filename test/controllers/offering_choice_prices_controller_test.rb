require "test_helper"

# S-20: a choice's client prices as a grid (BKG-21, BKG-23, ACC-30, ACC-31).
class OfferingChoicePricesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin)
    @departure = @alpha.departure
    @offering = @alpha.offering
    @cabin = @offering.choices.find_by!(name: "Cabin")
    @tour = @offering.choices.find_by!(name: "Private Miami tour")
    @v01 = @cabin.options.find_by!(label: "V01")
    @child = @agency.traveler_types.find_by!(name: "Child 0–4")
  end

  test "the cabin grid follows the supplier's bands and shows net supplier cost under each price" do
    sign_in_as @admin
    get edit_departure_offering_choice_prices_path(@departure, @offering, @cabin)
    assert_response :success
    assert_equal [ "Option", "1st and 2nd guest", "3rd and 4th guest", "Single" ], css_select("#client-prices thead th").map { |th| th.text.strip }
    assert_select "input[aria-describedby][id^='price_#{@v01.id}']", minimum: 1
    assert_select "label", text: "V01, 1st and 2nd guest: price"
    assert_equal "3385", css_select("input[name='prices[#{@v01.id}][guest_1+guest_2|]']").sole["value"]
    assert_equal "1285", css_select("input[name='prices[#{@v01.id}][guest_3+guest_4|]']").sole["value"]
    assert_select "tr", text: /V01.*Net supplier cost/m
    assert_select "tr", text: /V01.*3rd and 4th guest.*Holds 3 guests/m, count: 0
  end

  test "the hotel room grid uses the 1st guest and other guests" do
    sign_in_as @admin
    room = @offering.choices.find_by!(name: "Nov 5 hotel room")
    get edit_departure_offering_choice_prices_path(@departure, @offering, room)
    assert_equal [ "Option", "1st guest", "Other guests" ], css_select("#client-prices thead th").map { |th| th.text.strip }
  end

  test "saving writes only changed cells, on every position they cover, and drops an any-position price no guest can reach" do
    sign_in_as @admin
    get edit_departure_offering_choice_prices_path(@departure, @offering, @cabin)
    form = css_select("#client-prices input[name^='prices'], #client-prices input[name^='original']").to_h { |input| [ input["name"], input["value"].to_s ] }
    form["prices[#{@v01.id}][guest_3+guest_4|]"] = "1,300"

    assert_difference -> { AuditEvent.where(action: "departure.offering_price_set").count } => 1, -> { AuditEvent.where(action: "departure.offering_price_removed").count } => 1 do
      patch departure_offering_choice_prices_path(@departure, @offering, @cabin), params: form
    end
    assert_redirected_to departure_offerings_path(@departure, anchor: "choice-#{@cabin.id}")
    rows = @v01.prices.reload.where(traveler_type: nil).to_h { |price| [ price.occupancy_position, price.amount_minor_units ] }
    assert_equal({ "guest_1" => 338_500, "guest_2" => 338_500, "guest_3" => 130_000, "single" => 663_500 }, rows)
  end

  test "a traveler type gets its own column, and a blank typed cell removes its price" do
    sign_in_as @admin
    get edit_departure_offering_choice_prices_path(@departure, @offering, @cabin, traveler_type_id: @child.id)
    key = "guest_3+guest_4|#{@child.id}"
    assert_select "#client-prices thead th", text: "3rd and 4th guest, Child 0–4"
    assert_select "input[name='prices[#{@v01.id}][#{key}]'][placeholder='Same as any']"
    patch departure_offering_choice_prices_path(@departure, @offering, @cabin), params: { prices: { @v01.id => { key => "500" } }, original: { @v01.id => { key => "" } }, traveler_type_id: @child.id }
    assert_equal [ [ "guest_3", 50_000 ] ], @v01.prices.where(traveler_type: @child).pluck(:occupancy_position, :amount_minor_units)

    tour = @tour.options.sole
    get edit_departure_offering_choice_prices_path(@departure, @offering, @tour)
    assert_equal [ "Option", "Any traveler", "Child 0–4" ], css_select("#client-prices thead th").map { |th| th.text.strip }
    patch departure_offering_choice_prices_path(@departure, @offering, @tour), params: { prices: { tour.id => { "any|#{@child.id}" => "" } }, original: { tour.id => { "any|#{@child.id}" => "0" } } }
    assert_empty tour.prices.where(traveler_type: @child)
  end

  test "a room with no stated size prices other guests through the any-position price, which saving keeps" do
    sign_in_as @admin
    nights = @offering.choices.find_by!(name: "Extension nights")
    option = nights.options.find_by!(label: "Nov 1 Garden Queen")
    assert_nil option.inventory_group.positions_per_unit
    get edit_departure_offering_choice_prices_path(@departure, @offering, nights)
    assert_equal [ "Option", "1st guest", "Other guests" ], css_select("#client-prices thead th").map { |th| th.text.strip }
    other = "guest_2|"
    assert_equal "0", css_select("input[name='prices[#{option.id}][#{other}]']").sole["value"]

    first = "single+guest_1|"
    patch departure_offering_choice_prices_path(@departure, @offering, nights), params: {
      prices: { option.id => { first => "200", other => "25" } }, original: { option.id => { first => "190", other => "0" } }
    }
    assert_equal({ "guest_1" => 20_000, "any" => 2_500 }, option.prices.reload.to_h { |price| [ price.occupancy_position, price.amount_minor_units ] })
  end

  test "an invalid amount saves nothing and keeps what staff typed" do
    sign_in_as @admin
    key = "guest_1+guest_2|"
    assert_no_difference -> { OfferingPrice.count } do
      patch departure_offering_choice_prices_path(@departure, @offering, @cabin), params: {
        prices: { @v01.id => { key => "3,400", "single|" => "12.345" } }, original: { @v01.id => { key => "3385", "single|" => "6635" } }
      }
    end
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /V01, Single: enter an amount in USD/
    assert_equal "12.345", css_select("input[name='prices[#{@v01.id}][single|]']").sole["value"]
    assert_equal 338_500, @v01.prices.find_by!(occupancy_position: "guest_1").amount_minor_units
  end

  test "only Departure management edits prices; other agencies get not found" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get edit_departure_offering_choice_prices_path(@departure, @offering, @cabin)
    assert_redirected_to root_path

    sign_in_as agency_users(:cove_admin)
    get edit_departure_offering_choice_prices_path(@departure, @offering, @cabin)
    assert_response :not_found
  end
end
