require "application_system_test_case"

class M3D5SupplierReservationResponsesTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "System Response Supplier")
    @departure = create_capacity_departure(@agency, name: "System Response")
    @departure.update!(
      status: "active",
      departure_reference: "D-#{SecureRandom.random_number(900_000) + 100_000}",
      first_activated_at: Time.current
    )
    @graph = create_capacity_graph(
      agency: @agency,
      departure: @departure,
      contractor: @supplier,
      provider: @supplier,
      prefix: "System response",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end

  test "staff records a confirmed reservation response" do
    sign_in_from_browser(@staff)

    visit departure_arrangement_path(@departure, @arrangement)
    click_link "Reservations"
    click_link "Create planned reservation"
    select @supplier.display_name, from: "Booking Supplier"
    select "Whole Arrangement", from: "Scope target"
    fill_in "Scope note", with: "Whole booking"
    click_button "Create planned reservation"

    click_link "Record request sent"
    fill_in "Channel", with: "portal"
    fill_in "Request reference note", with: "Portal request"
    click_button "Record request sent"

    click_link "Record Supplier response"
    fill_in "Response channel", with: "portal"
    fill_in "Response reference note", with: "Supplier confirmed"
    fill_in "Confirmed without identifier reason", with: "Identifier follows later"
    click_button "Record response"

    assert_text "Reservation response recorded."
    assert_text "Confirmed"
  end

  test "failed response preserves submitted values and focuses the error summary" do
    sign_in_from_browser(@staff)

    visit departure_arrangement_path(@departure, @arrangement)
    click_link "Reservations"
    click_link "Create planned reservation"
    select @supplier.display_name, from: "Booking Supplier"
    select "Whole Arrangement", from: "Scope target"
    fill_in "Scope note", with: "Whole booking"
    click_button "Create planned reservation"

    click_link "Record request sent"
    fill_in "Channel", with: "portal"
    fill_in "Request reference note", with: "Portal request"
    click_button "Record request sent"

    click_link "Record Supplier response"
    fill_in "Response channel", with: "portal"
    fill_in "Response reference note", with: "Missing attestation"
    click_button "Record response"

    assert_selector "#form-error-summary", text: /identifier|evidence|confirm|Please fix/i
    assert_equal "form-error-summary", page.evaluate_script("document.activeElement && document.activeElement.id")
    assert_field "Response reference note", with: "Missing attestation"
  end
end
