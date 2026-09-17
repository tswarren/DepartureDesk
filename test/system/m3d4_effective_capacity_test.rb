require "application_system_test_case"

class M3d4EffectiveCapacityTest < ApplicationSystemTestCase
  include CapacityGraphHelper
  include CapacityActivatedGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @departure = create_capacity_departure(@agency, name: "Browser Effective Capacity")
    @contractor = create_capacity_supplier(@agency, "Browser Capacity Contractor")
    @provider = create_capacity_supplier(@agency, "Browser Capacity Provider")
    @graph = build_activated_established_capacity_graph(
      actor: @staff,
      prefix: "Browser cabin block",
      recorded_at: Time.zone.parse("2026-06-01 12:00:00 UTC")
    )
  end

  test "staff reaches the activated Pool and records a Supplier-backed change" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_path(@departure, @graph[:arrangement])

    assert_selector "#current-supplier-capacity", text: "Current Supplier capacity"
    click_link @graph[:pool_definition].label

    assert_selector "h1.dd-page-title", exact_text: @graph[:pool_definition].label
    assert_text "Current Supplier capacity"
    within "form[action='#{departure_arrangement_capacity_pool_events_path(
      @departure, @graph[:arrangement], @graph[:pool]
    )}']" do
      select "Increased", from: "Event type"
      fill_in "Quantity", with: "2"
      select "Supplier confirmation", from: "Evidence kind"
      fill_in_html_date "Evidence date", "2026-09-17"
      fill_in "Evidence reference note", with: "Supplier approved two additional cabins."
      click_button "Record capacity event"
    end

    assert_text "Capacity event recorded."
    assert_text "10 cabins"
    assert_equal 10, @graph[:projection].reload.current_supplier_capacity
  end
end
