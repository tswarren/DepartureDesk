require "test_helper"

# S-28, S-29 and receipts: who sees and records client money (CMN-19, CMN-55),
# credit and reversals on screen, and adjusting a draft's installments (CMN-09).
class ClientMoneyControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :paid)
    set_clock Time.utc(2027, 2, 3, 15)
    @rowan = @alpha.bookings.fetch("BK-101")
    @trip = @rowan.client_trip
  end

  test "every staff user sees the trip's money; only Financial records records it" do
    sign_in_as agency_users(:harbor_baseline_staff)
    get client_trip_path(@trip)
    assert_select "#money h2", text: "Client money"
    assert_select "#money ul[aria-label=Payments] li", text: /PAY-\d{5}.*\$500\.00 to the agency/m
    assert_select "#money a", text: "Record a payment", count: 0
    get new_client_trip_payment_path(@trip)
    assert_redirected_to root_path

    sign_in_as @admin
    get client_trip_path(@trip)
    assert_select "#money a", text: "Record a payment"
  end

  test "the receipt shows what the agency received and what it was applied to at issue" do
    receipt = @trip.client_payments.sole.receipt
    sign_in_as agency_users(:harbor_baseline_staff)
    get receipt_path(receipt)
    assert_select "h1", text: receipt.receipt_number
    assert_select "dd", text: "Nadia Rowan"
    assert_select "li", text: /#{@rowan.booking_reference}.*\$500\.00/m
  end

  test "a payment with nothing open is held as credit, and applied from the panel (CMN-23)" do
    sign_in_as @admin
    post client_trip_payments_path(@trip), params: { client_payment: {
      payer_client_id: @trip.client_id, paid_on: "2027-02-03", amount: "200", route: "agency", payment_method: "cash"
    } }
    follow_redirect!
    assert_select "#money div", text: /Credit not yet applied\s*\$200\.00/
    balance = @rowan.client_charge.installments.second
    assert_select "#apply-credit input[name='applications[#{balance.id}]'][value='200.00']"
    post client_trip_credit_application_path(@trip), params: { applications: { balance.id => "200" } }
    assert_equal 20_000, balance.reload.paid_minor_units
  end

  test "an invalid payment keeps what was typed; a reversal needs a reason" do
    sign_in_as @admin
    post client_trip_payments_path(@trip), params: { client_payment: {
      payer_client_id: @trip.client_id, paid_on: "2027-02-03", amount: "50.555", route: "agency", payment_method: "cash"
    } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Amount must be an amount in USD/
    assert_select "input[name='client_payment[amount]'][value='50.555']"

    payment = @trip.client_payments.sole
    post client_trip_payment_reversal_path(@trip, payment), params: { reason: "" }
    assert_response :unprocessable_entity
    post client_trip_payment_reversal_path(@trip, payment), params: { reason: "Check returned unpaid" }
    assert payment.reload.reversed?
    follow_redirect!
    assert_select "#money li", text: /Reversed.*Check returned unpaid/m
  end

  test "staff adjust a draft's proposed installments, which must total the price (CMN-09)" do
    booking = CreateClientBooking.new(agency: @agency, actor: @admin, trip: @trip).call.record
    traveler = @trip.client.travelers.find_by!(given_names: "Nadia")
    SaveBookingTraveler.new(agency: @agency, actor: @admin, booking:, attributes: { traveler_id: traveler.id, traveler_type_id: @agency.traveler_types.find_by!(name: "Adult").id }).call
    SaveChoiceSelection.new(agency: @agency, actor: @admin, booking:, attributes: {
      offering_option_id: @alpha.offering.choices.find_by!(name: "Cabin").options.find_by!(label: "I01").id, occupant_ids: booking.booking_travelers.reload.map(&:id)
    }).call
    deposit, balance = booking.installment_proposals.reload.to_a
    assert_equal [ 50_000, "at_confirmation" ], deposit.values_at(:amount_minor_units, :due_kind)
    total = booking.price_lines.sum(&:amount_minor_units)

    RecordBookingAcceptance.new(agency: @agency, actor: @admin, booking: booking.reload, attributes: { accepted_by: "Nadia Rowan", acceptance_method: "phone", note: "Yes." }).call
    assert booking.reload.current_acceptance, "the acceptance covers the proposals as proposed"

    sign_in_as agency_users(:harbor_baseline_staff)
    patch client_booking_installment_proposals_path(booking), params: { proposals: { deposit.id => { amount: "600", due: "at_confirmation" }, balance.id => { amount: "1", due: "on_date", due_on: "2027-07-09" } } }
    follow_redirect!
    assert_select ".dd-alert--danger", text: /must total the price/
    patch client_booking_installment_proposals_path(booking), params: { proposals: {
      deposit.id => { amount: "600", due: "at_confirmation" }, balance.id => { amount: MoneyInput.display(total - 60_000, "USD").delete(","), due: "on_date", due_on: "2027-06-01" }
    } }
    assert_equal [ [ 60_000, true ], [ total - 60_000, true ] ], booking.installment_proposals.reload.map { |row| [ row.amount_minor_units, row.adjusted ] }
    assert_equal Date.new(2027, 6, 1), booking.installment_proposals.second.due_on
    assert_nil booking.reload.current_acceptance, "adjusting the installments makes the acceptance stale (BKG-39)"
  end

  test "a booking shows its money and opens the payment form, which returns to it" do
    sign_in_as @admin
    get client_booking_path(@rowan, step: "price")
    assert_select "#booking-money dd", text: "$500.00"
    form_path = new_client_trip_payment_path(@trip, booking_id: @rowan.id, step: "price")
    assert_select "#booking-money a[href='#{form_path}']", text: "Record a payment"
    get client_booking_path(@rowan, step: "confirm")
    assert_select "#confirm #booking-money a", text: "Record a payment"

    get form_path
    assert_select "input[type=hidden][name=booking_id][value='#{@rowan.id}']"
    post client_trip_payments_path(@trip), params: { booking_id: @rowan.id, step: "price", client_payment: {
      payer_client_id: @trip.client_id, paid_on: "2027-02-03", amount: "100", route: "agency", payment_method: "cash"
    } }
    assert_redirected_to client_booking_path(@rowan, step: "price", anchor: "booking-money")

    sign_in_as agency_users(:harbor_baseline_staff)
    get client_booking_path(@rowan, step: "price")
    assert_select "#booking-money dl"
    assert_select "#booking-money a", text: "Record a payment", count: 0
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get receipt_path(@trip.client_payments.sole.receipt)
    assert_response :not_found
    get new_client_trip_payment_path(@trip)
    assert_response :not_found
  end
end
