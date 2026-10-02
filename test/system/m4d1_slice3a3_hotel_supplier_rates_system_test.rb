# frozen_string_literal: true

require "application_system_test_case"

class M4d1Slice3a3HotelSupplierRatesSystemTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton Fort Lauderdale Marina")
    @departure = create_capacity_departure(@agency, name: "Smith Family Cruise")
    @departure.update!(time_zone: "America/New_York")
  end

  test "staff saves hilton supplier rates and reviews the pretax block" do
    sign_in_from_browser(@staff)
    visit suppliers_departure_composition_path(@departure)
    click_link_and_expect "Add Hotel stay", heading: @departure.name, path: new_departure_composition_suppliers_hotel_path(@departure)

    fill_in "Stay name", with: "Pre-cruise hotel stay"
    fill_in_html_date "Arrival date", "2027-11-04"
    fill_in_html_date "Departure date", "2027-11-06"
    find("#arrangement_contracting_supplier_id option[value='#{@contractor.id}']").select_option
    click_button "Save and continue"

    fill_in "resource_name", with: "Standard"
    fill_in "resource_maximum_occupancy", with: "4"
    click_button "Add room category"
    assert_text "Standard"
    assert_text "Maximum occupancy 4"
    fill_in "resource_name", with: "Deluxe"
    fill_in "resource_maximum_occupancy", with: "4"
    click_button "Add room category"
    assert_text "Deluxe"

    item = ArrangementItemDefinition.find_by!(agency: @agency, name: "Pre-cruise hotel stay").arrangement_item
    standard = resource_named(item, "Standard")
    deluxe = resource_named(item, "Deluxe")
    {
      [ standard, "2027-11-04" ] => "5",
      [ deluxe, "2027-11-04" ] => "2",
      [ standard, "2027-11-05" ] => "10",
      [ deluxe, "2027-11-05" ] => "5"
    }.each do |(category, date), quantity|
      fill_in "quantity_#{category.supplier_resource_id}_#{date}", with: quantity
    end
    select "Contract", from: "Evidence"
    find("#evidence_on").execute_script("this.value = arguments[0]", "2026-09-30")
    fill_in "Reference note", with: "Hilton group contract"
    click_button "Save room inventory"
    assert_text "Room inventory saved."

    click_link "Edit rates"
    assert_selector "h1", text: @departure.name
    assert_selector "h2", text: "Supplier rates"
    assert_selector "a.dd-skip-link[href='#main-content']", text: "Skip to main content", visible: :all
    assert_no_text "Review & activate"
    assert_no_text "$685"

    find("#base_#{standard.supplier_resource_id}").click
    page.driver.browser.action.send_keys(:tab).perform
    assert_equal "base_#{deluxe.supplier_resource_id}", page.evaluate_script("document.activeElement.id")

    fill_in "Standard room night base", with: "173"
    fill_in "Deluxe room night base", with: "223"
    fill_in "Third occupant", with: "20"
    fill_in "Fourth occupant", with: "20"
    check "Net and noncommissionable"
    click_button "Save Supplier rates"
    assert_text "Supplier rates saved."
    assert_text "Standard: $173.00 / $173.00 / $193.00 / $213.00"
    assert_text "Deluxe: $223.00 / $223.00 / $243.00 / $263.00"
    assert_text "Nov 4 base block: $1,311.00"
    assert_text "Nov 5 base block: $2,845.00"
    assert_text "Current pretax contracted-room total: $4,156.00"
    assert_no_text "$8,312"
    assert_no_text "$685.74"

    [ 375, 768, 1280 ].each do |width|
      resize_window(width, 900)
      assert_no_page_overflow
      assert_selector "h1", text: @departure.name
      assert_selector "#hotel-setup-nav"
      assert_selector "#hotel-block-total"
    end
  end

  private

  def resource_named(item, name)
    item.supplier_arrangement.editable_version.supplier_resource_definitions.find_by!(arrangement_item: item, name: name)
  end
end
