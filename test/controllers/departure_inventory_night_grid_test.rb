require "test_helper"

# S-17: a hotel's rooms by night as a grid (INV-01, INV-13, INV-38).
class DepartureInventoryNightGridTest < ActionDispatch::IntegrationTest
  test "the night grid counts what bookings hold on each night" do
    set_clock Time.utc(2027, 1, 12, 15)
    agency = agencies(:harbor)
    alpha = AlphaFixture.load!(agency:, actor: agency_users(:harbor_admin), bookings: :held)
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_inventory_path(alpha.departure)
    assert_select "table.dd-night-grid a[aria-label='Nov 4 Harbor Double: 0 of 1 left']"
    assert_select "table.dd-night-grid td", text: /0 of 1 left\s+1 held or reserved/
    assert_select "table.dd-night-grid a[aria-label='Nov 4 Garden Queen: 0 of 2 left']"
    get departure_arrangement_inventory_path(alpha.departure, alpha.arrangements.fetch(:hotel))
    assert_select "#inventory table.dd-night-grid a[aria-label='Nov 4 Harbor Double: 0 of 1 left']"
  end
end
