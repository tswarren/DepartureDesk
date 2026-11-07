require "application_system_test_case"

# Demonstration case D5 (first-slice charter, as amended by D-94). Rules: BKG-39, BKG-41.
class DemonstrationD5Test < ApplicationSystemTestCase
  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @scenario = AlphaScenario.load!(bookings: :held)
    @alpha = @scenario.alpha
    @booking = @alpha.bookings.fetch("BK-101")
  end

  teardown do
    AlphaScenario.cleanup!(@scenario)
  end

  test "D5: confirmation needs recorded acceptance" do
    sign_in_from_browser(@scenario.baseline_staff, password: M1DirectoryScenario::PASSWORD)
    visit client_booking_path(@booking)
    click_button "Confirm booking"
    within("#form-error-summary") { assert_link "Record the client's acceptance of the current price and terms.", href: "#acceptance" }
    assert @booking.reload.status_draft?

    within("#acceptance") { click_link "Record acceptance" }
    within("#booking_acceptance_acceptance_method") do
      assert_no_text "paid" # Alpha's deposit doesn't count as acceptance (D-93)
      choose "Email"
    end
    click_button "Record acceptance"
    assert_text "Evidence is required for email or signed acceptance"
    fill_in "Where it is kept (optional)", with: "Nadia's email of Jan 12, bookings mailbox"
    choose "Email"
    click_button "Record acceptance"
    assert_text "Acceptance recorded."
    within("#acceptance") { assert_text "Covers the current price and terms" }

    click_button "Confirm booking"
    assert_text "Booking confirmed."
    assert @booking.reload.status_confirmed?
    within("#confirm") { assert_text "Confirmed Jan 12, 2027" }
  end
end
