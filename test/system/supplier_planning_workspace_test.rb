require "application_system_test_case"

class SupplierPlanningWorkspaceTest < ApplicationSystemTestCase
  test "administrator works supplier planning create confirm hold flow and sees transfer freeze" do
    supplier = parties(:organization_one)
    assign_supplier_role!(supplier, actor: users(:one)) unless supplier.supplier_profile
    departure = create_departure!(agencies(:one), actor: users(:one), name: "Smith Supplier Workspace")
    StartDeparturePlanning.new(agency: agencies(:one), actor: users(:one), departure:).call

    sign_in_from_browser(users(:one))
    visit departure_path(departure)

    click_link_and_expect "Open supplier planning", heading: "Smith Supplier Workspace", path: departure_supplier_arrangements_path(departure)
    assert_text "Forecast and exposure"
    assert_no_text "Client balance"

    select "Horizon Tours (Organization) · supplier active", from: "Contracting supplier *"
    fill_in "Name *", with: "Smith Cruise Agreement"
    click_button "Create draft arrangement"
    assert_selector "h1.dd-page-title", text: "Smith Cruise Agreement"

    within("#resources") do
      fill_in "Resource name", with: "Balcony Cabins"
      fill_in "Resource kind", with: "cabin_category"
      select "Cabin", from: "Capacity unit"
      click_button "Create resource"
    end
    assert_text "Supplier resource created."

    within("#resources") do
      select "Balcony Cabins", from: "Resource"
      select "Typed segment", from: "Occurrence kind"
      fill_in "Segment type", with: "sailing"
      fill_in "Segment identifier", with: "MAIN"
      click_button "Create occurrence"
    end
    assert_text "Supplier occurrence created."

    within("#capacity") do
      select "Balcony Cabins", from: "Resource"
      select "Balcony Cabins · Sailing · MAIN", from: "Occurrence"
      fill_in "Held quantity", with: "12"
      fill_in "Guaranteed quantity", with: "12"
      fill_in "Reason", with: "Initial cabin guarantee"
      click_button "Hold capacity"
    end
    assert_text "Supplier capacity held."
    assert_text "Guaranteed"
    assert_text "Available"

    within("#confirmations") do
      fill_in "Identifier", with: "CRU-2027-001"
      click_button "Record confirmation"
    end
    assert_text "Supplier confirmation recorded."

    within("#reservations") do
      fill_in "Reservation name", with: "Cabin request 101"
      select "Balcony Cabins", from: "Linked resources"
      click_button "Create reservation"
    end
    assert_text "Supplier reservation created."

    within("#reservations") do
      fill_in "Reason if no identifier", with: "Supplier confirmed by phone before issuing cabin-level reference"
      click_button "Confirm"
    end
    assert_text "Supplier reservation confirmed."
    assert_text "Confirmed"

    visit departure_path(departure)
    assert_text "Office transfer is unavailable because supplier arrangements exist"
    assert_button "Transfer office", disabled: true
  end
end
