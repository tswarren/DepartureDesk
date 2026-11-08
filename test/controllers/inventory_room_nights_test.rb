require "test_helper"

# Hotel rooms by night: one group per night and room type (INV-01, INV-13).
class InventoryRoomNightsTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, confirm_cruise: false)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Harbor weekend", time_zone: "America/New_York" }).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure,
      supplier_id: @alpha.arrangements.fetch(:hotel).supplier_id, attributes: {}).call.record
  end

  def setup_params
    { first_night: "2027-11-03", last_night: "2027-11-05", room_types: { "0" => { name: "Garden Queen", guests: "2" }, "1" => { name: "Harbor Double", guests: "4" } } }
  end

  test "the first step lays out a grid of nights by room type" do
    sign_in_as @admin
    get new_departure_arrangement_room_nights_path(@departure, @arrangement, **setup_params)
    assert_equal %w[Night Garden\ Queen Harbor\ Double], css_select("#room-night-grid thead th").map { |th| th.children.first.text.strip }
    assert_equal [ "Nov 3", "Nov 4", "Nov 5" ], css_select("#room-night-grid tbody th").map { |th| th.text.strip }
  end

  test "adding rooms makes one group per night and type held, each its own night" do
    sign_in_as @admin
    cells = {
      "2027-11-03|Garden Queen" => { kind: "on_request" }, "2027-11-03|Harbor Double" => { kind: "skip" },
      "2027-11-04|Garden Queen" => { kind: "firm", count: "2" }, "2027-11-04|Harbor Double" => { kind: "firm", count: "1" },
      "2027-11-05|Garden Queen" => { kind: "tracked", count: "4" }, "2027-11-05|Harbor Double" => { kind: "tracked", count: "4" }
    }
    post departure_arrangement_room_nights_path(@departure, @arrangement), params: setup_params.merge(cells:)
    assert_redirected_to departure_arrangement_path(@departure, @arrangement, anchor: "inventory")
    groups = @arrangement.inventory_groups.reload.index_by(&:label)
    assert_equal [ "Nov 3 Garden Queen", "Nov 4 Garden Queen", "Nov 4 Harbor Double", "Nov 5 Garden Queen", "Nov 5 Harbor Double" ], groups.keys.sort
    assert_equal [ "capacity_pool", "on_request", nil ], groups.fetch("Nov 3 Garden Queen").values_at(:representation, :availability_promise, :quantity)
    assert_equal [ "capacity_pool", "firm_block", 2 ], groups.fetch("Nov 4 Garden Queen").values_at(:representation, :availability_promise, :quantity)
    assert_equal [ "unit_shells", 4, 4, Date.new(2027, 11, 5), Date.new(2027, 11, 6) ],
      groups.fetch("Nov 5 Harbor Double").values_at(:representation, :quantity, :positions_per_unit, :starts_on, :ends_on)
    assert_equal "Harbor Double", @alpha.offering.choices.first.options.new(label: "Nov 5 Harbor Double", inventory_group: groups.fetch("Nov 5 Harbor Double")).night_kind
  end

  test "a firm night with no count adds nothing and keeps the grid" do
    sign_in_as @admin
    post departure_arrangement_room_nights_path(@departure, @arrangement), params: setup_params.merge(cells: {
      "2027-11-03|Garden Queen" => { kind: "on_request" }, "2027-11-04|Garden Queen" => { kind: "firm", count: "" }
    })
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Nov 4 Garden Queen: enter how many rooms/
    assert_select "#room-night-grid"
    assert_empty @arrangement.inventory_groups.reload
  end
end
