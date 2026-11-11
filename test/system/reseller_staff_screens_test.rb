require "application_system_test_case"

# Slice 1 step 9a screens: S-04 Resellers, S-10 reseller channels on the
# Package tab, and the booking Summary's owner and seller, at desktop width
# and 375px.
class ResellerStaffScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :confirmed)
    @alpha = @scenario.alpha
    set_clock Time.utc(2027, 2, 3, 15)
    @reseller = SaveReseller.new(agency: @scenario.agency, actor: @scenario.actor, attributes: { name: "Coral Coast Travel" }).call.record
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "staff publish the package to Coral Coast Travel and assign it a booking, and the screens reflow at 375px" do
    booking = @alpha.bookings.fetch("BK-105")
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)

    visit departure_offerings_path(@alpha.departure)
    within("#channels-#{@alpha.offering.id}") do
      assert_text "Not published"
      click_button "Publish"
    end
    assert_text "#{@alpha.offering.name} published to Coral Coast Travel."
    within("#channels-#{@alpha.offering.id}") { assert_text "Published" }

    visit client_booking_path(booking)
    within("#summary-sales") do
      find("summary", text: "Change the owner").click
      select "Coral Coast Travel", from: "Owner"
      click_button "Save owner"
    end
    assert_text "Booking assigned to Coral Coast Travel."
    within("#summary-sales") { assert_text "Coral Coast Travel" }

    paths = [ resellers_path, new_reseller_path, reseller_path(@reseller), edit_reseller_path(@reseller), departure_offerings_path(@alpha.departure), client_booking_path(booking) ]
    [ 1400, 375 ].each do |width|
      resize_window(width)
      paths.each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_no_page_overflow
      end
    end
  end
end
