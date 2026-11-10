require "test_helper"

# S-27 and the confirmed booking: acceptance is baseline work (ACC-30),
# evidence downloads go through the app (ADR 0019 amendment), supplier
# cost shows only with view_supplier_costs (ACC-31).
class BookingAcceptanceControllerTest < ActionDispatch::IntegrationTest
  PDF = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF\n".b

  setup do
    set_clock Time.utc(2027, 1, 12, 15)
    @agency = agencies(:harbor)
    @staff = agency_users(:harbor_baseline_staff)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :held)
    @booking = @alpha.bookings.fetch("BK-101")
  end

  test "staff record acceptance with an evidence file, download it, and confirm" do
    sign_in_as @staff
    get new_client_booking_acceptance_path(@booking)
    assert_select "h1", text: "Record acceptance"
    assert_select "input[name='booking_acceptance[acceptance_method]'][value='designated_payment']", count: 0

    file = Rack::Test::UploadedFile.new(StringIO.new(PDF), "application/pdf", original_filename: "nadia-acceptance.pdf")
    post client_booking_acceptances_path(@booking), params: { booking_acceptance: { accepted_by: "Nadia Rowan", acceptance_method: "email", accepted_on: "2027-01-12", evidence: file } }
    assert_redirected_to client_booking_path(@booking, step: "confirm", anchor: "acceptance")
    acceptance = @booking.acceptances.sole

    get client_booking_acceptance_evidence_path(@booking, acceptance)
    assert_response :success
    assert_equal PDF, response.body
    assert_match(/sandbox/, response.headers["Content-Security-Policy"])

    post client_booking_confirmation_path(@booking)
    assert_redirected_to client_booking_path(@booking, step: "confirm", anchor: "confirm")
    assert @booking.reload.status_confirmed?
    get client_booking_path(@booking, step: "confirm")
    assert_select "#supplier-cost", count: 0, text: nil
    assert_select "#acceptance a", text: "nadia-acceptance.pdf"
  end

  test "a refused acceptance re-renders with the error on its field" do
    sign_in_as @staff
    post client_booking_acceptances_path(@booking), params: { booking_acceptance: { accepted_by: "Nadia Rowan", acceptance_method: "phone" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary a[href='#booking_acceptance_note']"
  end

  test "supplier cost shows for cost-viewing users and overrides need a permission" do
    RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: { accepted_by: "Nadia Rowan", acceptance_method: "phone", note: "Yes." }).call
    ConfirmClientBooking.new(agency: @agency, actor: @staff, booking: @booking).call
    commission = @booking.reload.expected_commissions.sole

    sign_in_as agency_users(:harbor_staff)
    get client_booking_path(@booking, step: "confirm")
    assert_select "#supplier-cost th", text: /Cabin 1: V01/
    assert_select "#supplier-cost input[type=submit][value=Override]", count: 0
    patch client_booking_commission_path(@booking, commission), params: { amount: "1" }
    follow_redirect!
    assert_select ".dd-alert--danger"
    assert_equal commission.proposed_amount_minor_units, commission.reload.amount_minor_units

    sign_in_as @admin
    patch client_booking_commission_path(@booking, commission), params: { amount: "900" }
    assert_equal 90_000, commission.reload.amount_minor_units
  end

  test "locked terms start a next version for new bookings" do
    RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking, attributes: { accepted_by: "Nadia Rowan", acceptance_method: "phone", note: "Yes." }).call
    sign_in_as @admin
    get departure_client_terms_path(@alpha.departure)
    assert_select "button", text: "Start version 2"
    post departure_client_terms_next_version_path(@alpha.departure)
    assert_equal 2, @alpha.departure.reload.current_client_terms.version_number
  end

  test "other agencies get not found" do
    acceptance = RecordBookingAcceptance.new(agency: @agency, actor: @staff, booking: @booking,
      attributes: { accepted_by: "Nadia Rowan", acceptance_method: "email" },
      evidence: Rack::Test::UploadedFile.new(StringIO.new(PDF), "application/pdf", original_filename: "a.pdf")).call.record
    sign_in_as agency_users(:cove_admin)
    get client_booking_acceptance_evidence_path(@booking, acceptance)
    assert_response :not_found
    get new_client_booking_acceptance_path(@booking)
    assert_response :not_found
  end
end
