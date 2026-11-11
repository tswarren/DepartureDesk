require "application_system_test_case"

# Slice 1 step 9b screens R-01 to R-03, the reseller's start and traveler
# forms, and S-04's invite form, at desktop width and 375px.
class ResellerScreensTest < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @scenario = AlphaScenario.load!(bookings: :held)
    @alpha = @scenario.alpha
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "the reseller's screens reflow at 375px without page overflow" do
    booking = @alpha.bookings.fetch("BK-105")
    paths = [
      reseller_root_path, reseller_offer_path(@alpha.offering), new_reseller_offer_booking_path(@alpha.offering),
      *BookingProgress::STEPS.excluding("money").map { |step| reseller_client_booking_path(booking, step:) },
      new_reseller_client_booking_acceptance_path(booking), edit_reseller_traveler_path(booking.booking_travelers.first.traveler, booking_id: booking.id)
    ]
    sign_in_from_browser(@alpha.reseller_user, password: M1DirectoryScenario::PASSWORD)
    assert_selector "h1", text: "Offers and bookings"
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

  test "S-04's users panel and invite form reflow at 375px" do
    sign_in_from_browser(@scenario.actor, password: M1DirectoryScenario::PASSWORD)
    [ 1400, 375 ].each do |width|
      resize_window(width)
      [ reseller_path(@alpha.reseller), new_reseller_user_path(@alpha.reseller), clients_path(creator: "reseller") ].each do |path|
        visit path
        wait_for_turbo
        assert_selector "h1.dd-page-title"
        assert_no_page_overflow
      end
    end
  end
end
