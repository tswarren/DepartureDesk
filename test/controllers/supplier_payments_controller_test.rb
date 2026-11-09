require "test_helper"

# S-30, S-31 and commission confirmation: who records supplier money (SMN-18,
# SMN-33, ACC-31), applying what isn't applied, and reversals on screen.
class SupplierPaymentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :paid)
    set_clock Time.utc(2027, 2, 3, 15)
    @departure = @alpha.departure
    @cruise = @alpha.arrangements.fetch(:cruise)
    @payment = @departure.supplier_payments.sole
  end

  test "the Supplier money tab lists the paid amounts and payments; only Financial records records one" do
    sign_in_as agency_users(:harbor_staff)
    get departure_supplier_money_path(@departure)
    assert_select "#amounts-due td", text: /Paid/
    assert_select "#supplier-payments li", text: /#{@payment.payment_reference}.*\$2,950\.00.*Wire 0203/m
    assert_select "#supplier-payments a", text: /Record a payment/, count: 0
    get new_departure_supplier_payment_path(@departure, supplier_id: @cruise.supplier_id)
    assert_redirected_to root_path

    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_supplier_money_path(@departure)
    assert_redirected_to root_path
  end

  test "a payment made before anything is open stays unapplied, then is applied from the tab (SMN-22)" do
    sign_in_as @admin
    post departure_supplier_payments_path(@departure), params: { supplier_id: @cruise.supplier_id, supplier_payment: { amount: "100", paid_on: "2027-02-03", payment_method: "check" } }
    follow_redirect!
    assert_select "#supplier-payments div", text: /Paid, not yet applied\s*\$100\.00/
    ReverseSupplierPayment.new(agency: @agency, actor: @admin, payment: @payment, reason: "Wire returned").call
    get departure_supplier_money_path(@departure)
    first = @cruise.amounts_due.by_due.first
    assert_select "#apply-#{@cruise.supplier_id} input[name='applications[#{first.id}]'][value='100.00']"
    post departure_supplier_payment_application_path(@departure), params: { supplier_id: @cruise.supplier_id, applications: { first.id => "100" } }
    assert_equal 10_000, first.reload.paid_minor_units
  end

  test "a reversal needs a reason; an invalid payment keeps what was typed" do
    sign_in_as @admin
    post departure_supplier_payment_reversal_path(@departure, @payment), params: { reason: "" }
    assert_response :unprocessable_entity
    post departure_supplier_payment_reversal_path(@departure, @payment), params: { reason: "Wire returned by the bank" }
    assert @payment.reload.reversed?

    post departure_supplier_payments_path(@departure), params: { supplier_id: @cruise.supplier_id, supplier_payment: { amount: "1.234", paid_on: "2027-02-03", payment_method: "check" } }
    assert_response :unprocessable_entity
    assert_select "[role=alert]", text: /Amount must be an amount in USD/
    assert_select "input[name='supplier_payment[amount]'][value='1.234']"
  end

  test "staff with Supplier arrangements confirm a booking's commission with the supplier's amount (SMN-33)" do
    booking = @alpha.bookings.fetch("BK-101")
    commission = booking.expected_commissions.sole
    sign_in_as agency_users(:harbor_staff)
    get client_booking_path(booking, step: "confirm")
    assert_select "#supplier-cost input[aria-label='Confirm the commission for #{commission.choice_selection.label}']", count: 0

    staff = agency_users(:harbor_baseline_staff)
    UserPermission.create!(agency: @agency, agency_user: staff, permission: "supplier_arrangements")
    sign_in_as staff
    get client_booking_path(booking, step: "confirm")
    assert_select "#supplier-cost input[name=amount][value='1085.00']"
    post client_booking_commission_confirmation_path(booking, commission), params: { amount: "1085" }
    assert_redirected_to client_booking_path(booking, step: "confirm", anchor: "supplier-cost")
    follow_redirect!
    assert_select "#supplier-cost td", text: /Commission\s+Confirmed/
    assert_select "#supplier-cost td", text: /Confirmed; can't be overridden/
  end

  test "other agencies get not found" do
    sign_in_as agency_users(:cove_admin)
    get new_departure_supplier_payment_path(@departure, supplier_id: @cruise.supplier_id)
    assert_response :not_found
    get new_departure_supplier_payment_reversal_path(@departure, @payment)
    assert_response :not_found
  end
end
