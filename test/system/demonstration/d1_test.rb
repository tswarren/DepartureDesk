require "application_system_test_case"

# Demonstration case D1 (first-slice charter). Rules: SUP-12, SUP-35, INV-38, D-75.
class DemonstrationD1Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @scenario = AlphaScenario.load!(confirm_cruise: false)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D1: staff confirm the Alpha arrangement" do
    cruise = @alpha.arrangements.fetch(:cruise)
    assert cruise.draft?
    assert_equal 0, UnitShell.where(inventory_group: cruise.inventory_groups).count, "no shells before confirmation"

    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    visit departure_path(@alpha.departure)
    click_link_and_expect "Suppliers", heading: "Alpha Omega", path: departure_arrangements_path(@alpha.departure), css: "nav[aria-label='Departure sections'] a"
    click_link_and_expect cruise.arrangement_reference, heading: "Alpha Cruises"
    within("#rate-table") { assert_text "I01" }
    click_link_and_expect "Confirm arrangement", heading: "Confirm arrangement", css: ".dd-page-actions a"
    fill_in_html_date "Date the supplier confirmed", "2026-10-01"
    click_button_and_expect "Confirm arrangement", text: "Frozen when the arrangement was confirmed."

    cruise.reload
    assert cruise.confirmed?
    shells = UnitShell.where(inventory_group: cruise.inventory_groups).includes(:inventory_group, :capacity_events)
    assert_equal 32, shells.size
    assert_equal({ "V01" => [ 3 ] * 8, "O01" => [ 3 ] * 8, "I01" => [ 3 ] * 8, "S01" => [ 4 ] * 8 },
      shells.group_by { |shell| shell.inventory_group.label }.transform_values { |group| group.sort_by(&:position).map(&:positions) })
    assert shells.all? { |shell| shell.status == "available" }
    assert_no_supplier_cost

    click_link_and_expect "Inventory", heading: "Alpha Omega", path: departure_inventory_path(@alpha.departure), css: "nav[aria-label='Departure sections'] a"
    %w[V01 O01 I01 S01].each do |label|
      assert_selector "ul[aria-label='#{label} shells'] li", text: "Available", count: 8
    end
  end

  private

  # D-75: confirmation records no supplier cost. No cost or commission table
  # may hold a row for this agency (cost lines arrive in build step 4).
  def assert_no_supplier_cost
    connection = ActiveRecord::Base.connection
    connection.tables.grep(/cost|commission/).each do |table|
      count = connection.select_value("SELECT count(*) FROM #{connection.quote_table_name(table)} WHERE agency_id = #{connection.quote(@scenario.agency.id)}")
      assert_equal 0, count.to_i, "#{table} holds a supplier cost after confirmation"
    end
  end
end
