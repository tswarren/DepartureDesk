require "application_system_test_case"

class M3D5SupplierReservationsTest < ApplicationSystemTestCase
  setup do
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_staff)
    @supplier = create_capacity_supplier(@agency, "System Reservation Supplier")
    @departure = create_capacity_departure(@agency, name: "System Reservation")
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
      prefix: "System reservation",
      capacity_management: "unmanaged"
    )
    @arrangement = @graph[:arrangement]
    @version = @graph[:version]
    @version.update!(status: "activated", activated_at: Time.current)
    @arrangement.update!(status: "active", governing_version: @version)
  end

  test "staff plans requests and withdraws a reservation" do
    sign_in_from_browser(@staff)

    visit departure_arrangement_path(@departure, @arrangement)
    click_link "Reservations"
    click_link "Create planned reservation"

    select @supplier.display_name, from: "Booking Supplier"
    select "Whole Arrangement", from: "Scope 1 target"
    fill_in "Scope note", with: "Whole booking"
    click_button "Create planned reservation"

    assert_text "Reservation planned."
    assert_text "Planned"
    fill_in "Channel", with: "portal"
    fill_in "Request reference note", with: "Portal request"
    click_button "Record request sent"

    assert_text "Reservation request recorded."
    assert_text "Requested"
    fill_in "Withdrawal reason", with: "Supplier asked us to resend later"
    click_button "Record withdrawal"

    assert_text "Reservation withdrawal recorded."
    assert_text "Withdrawn"
  end
end
