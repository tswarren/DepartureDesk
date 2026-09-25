# frozen_string_literal: true

require "application_system_test_case"

class M4d1Slice3WorkspacesSystemTest < ApplicationSystemTestCase
  include CapacityGraphHelper

  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @contractor = create_capacity_supplier(@agency, "Hilton")
    @departure = create_capacity_departure(@agency, name: "Hilton stay")
    @setup = CreateHotelStaySetup.new(
      agency: @agency, actor: @staff, departure: @departure, idempotency_key: SecureRandom.uuid,
      arrangement_attributes: { name: "Hilton Waikiki", contracting_supplier_id: @contractor.id },
      item_attributes: { name: "Hilton Waikiki" },
      occurrence_attributes: { name: "Stay", starts_on: "2027-11-02", ends_on: "2027-11-05", time_zone: "America/New_York" }
    ).call
  end

  test "staff opens the hotel cost editor from the keyboard without page overflow" do
    sign_in_from_browser(@staff)
    visit departure_arrangement_hotel_path(@departure, @setup.record.arrangement)
    assert_text "Hilton Waikiki"
    [ 375, 768, 1280, 1400 ].each do |width|
      resize_window(width)
      assert_no_page_overflow
    end
    resize_window(1280)
    add_cost = find_link("Add Supplier cost")
    add_cost.send_keys(:return)
    assert_field "Label"
    fill_in "Label", with: ""
    fill_in "Amount", with: "20.00"
    click_on "Save"
    assert_selector "#form-error-summary"
    assert_field "Amount", with: "20.00"
    fill_in "Label", with: "Additional adult"
    click_on "Save"
    assert_text "Supplier cost saved."
    assert_text "Additional adult"
  end
end
