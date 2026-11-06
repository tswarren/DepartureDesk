require "test_helper"

# S-17: INV-04, INV-05, INV-38.
class DepartureInventoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @alpha = AlphaFixture.load!(agency: @agency, actor: agency_users(:harbor_admin), confirm_cruise: false)
    @departure = @alpha.departure
  end

  test "baseline staff see each arrangement's shells, pools and On request groups" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_inventory_path(@departure)
    assert_response :success
    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Inventory"

    assert_select "h2", text: "Alpha Cruises"
    assert_select "p", text: /Shells and pools are created when the arrangement is confirmed/
    assert_select "td", text: "Planned: 8 units, 3 positions each"

    assert_select "ul[aria-label='Nov 5 Garden Queen shells'] li", count: 4
    assert_select "ul[aria-label='Nov 5 Harbor Double shells'] li", text: /4 positions/, count: 4
    assert_select "tr", text: /Nov 4 Harbor Double.*Firm block.*1 place\b/m
    assert_select "tr", text: /Nov 1 Garden Queen.*On request.*On request/m
    assert_select "ul[aria-label='Private Miami tour shells'] li", text: /10 positions.*Available/m
    assert_no_match(/\$/, response.body, "inventory shows no supplier cost (ACC-31)")
  end

  test "after Confirm the cruise shows 32 shells, all Available" do
    cruise = @alpha.arrangements.fetch(:cruise)
    ConfirmSupplierArrangement.new(agency: @agency, actor: agency_users(:harbor_admin), departure: @departure, arrangement: cruise,
      confirmed_on: "2026-10-01", lock_version: cruise.lock_version).call
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_inventory_path(@departure)
    %w[V01 O01 I01 S01].each do |label|
      assert_select "ul[aria-label='#{label} shells'] li", text: /Available/, count: 8
    end
    assert_select "p", text: /8 available/, minimum: 4
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get departure_inventory_path(@departure)
    assert_response :not_found
  end

  test "the query count does not grow with more groups and shells" do
    sign_in_as agency_users(:harbor_admin)
    get departure_inventory_path(@departure)
    before = request_query_count { get departure_inventory_path(@departure) }

    cruise = @alpha.arrangements.fetch(:cruise)
    ConfirmSupplierArrangement.new(agency: @agency, actor: agency_users(:harbor_admin), departure: @departure, arrangement: cruise,
      confirmed_on: "2026-10-01", lock_version: cruise.lock_version).call
    after = request_query_count { get departure_inventory_path(@departure) }
    assert_equal before, after
  end

  private

  def request_query_count
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] unless payload[:name] == "SCHEMA" }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries.count { |sql| sql.start_with?("SELECT") }
  end
end
