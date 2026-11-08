require "test_helper"

# S-14: the rate grid page. Cost viewers see rates; Supplier arrangements edit them (ACC-31).
class SupplierRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, confirm_cruise: false)
    @departure = @alpha.departure
    @cruise = @alpha.arrangements.fetch(:cruise)
  end

  test "the arrangement shows the grid; the rate page edits it with shared values once" do
    sign_in_as @admin
    get departure_arrangement_path(@departure, @cruise)
    assert_select "#rate-table th", text: "3rd and 4th guest"
    assert_select "#rate-table a", text: "Edit rates"

    get edit_departure_arrangement_rates_path(@departure, @cruise)
    assert_select "h1", text: "Supplier rates"
    assert_select "input[name='rates[defaults][non_commissionable_fees]'][value='325']"
    assert_select "input[type=radio][name='rates[defaults][commission_method]'][value=percent][checked]"
    assert_select "[data-show-for=amount] input[name='rates[defaults][commission_amount]']"
    assert_select "input[name$='[override][non_commissionable_fees]'][value='650']", count: 4
    assert_select "td", text: /Not in a 3-guest unit/, count: 0
  end

  test "a refused save re-renders what was typed with the reason" do
    sign_in_as @admin
    grid = SupplierRateGrid.new(@cruise)
    v01 = @cruise.inventory_groups.find_by!(label: "V01")
    key = SupplierRateGrid.cell_key(v01, @cruise.rate_bands.first)
    patch departure_arrangement_rates_path(@departure, @cruise), params: { rates: { defaults: grid.defaults, cells: { key => { fare: "3,500.555", discount: "700" } } } }
    assert_response :unprocessable_entity
    assert_select ".dd-alert--danger", text: /V01, 1st and 2nd guest: the fare must be an amount in USD/
    assert_select "input[name='rates[cells][#{key}][fare]'][value='3,500.555']"
  end

  test "Departure management sees the rates but can't edit them; baseline staff never see them" do
    sign_in_as agency_users(:harbor_staff)
    get departure_arrangement_path(@departure, @cruise)
    assert_select "#rate-table"
    assert_select "#rate-table a", text: "Edit rates", count: 0
    get edit_departure_arrangement_rates_path(@departure, @cruise)
    assert_redirected_to root_path

    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_arrangement_path(@departure, @cruise)
    assert_select "#rate-table", count: 0
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get edit_departure_arrangement_rates_path(@departure, @cruise)
    assert_response :not_found
  end
end
