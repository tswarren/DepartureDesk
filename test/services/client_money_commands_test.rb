require "test_helper"

# Step 8a: installments, client payments, credit, reversals and receipts
# (CMN-08, CMN-09, CMN-12, CMN-18, CMN-21, CMN-23, CMN-24, CMN-27 to
# CMN-29, CMN-55, BKG-41; step 8 plan, questions 1 to 8).
class ClientMoneyCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    set_clock Time.utc(2027, 2, 3, 15)
    @rowan = @alpha.bookings.fetch("BK-101")
    @trip = @rowan.client_trip
  end

  def pay!(amount:, applications: nil, route: "agency", trip: @trip, actor: @admin, supplier: nil)
    installments = applications || [ { installment_id: trip.client_bookings.first.client_charge.installments.first.id, amount: } ]
    RecordClientPayment.new(agency: @agency, actor:, trip:, applications: installments, attributes: {
      payer_client_id: trip.client_id, paid_on: "2027-01-12", amount:, route:, supplier_id: supplier&.id, payment_method: "check", reference: "Check 1047"
    }).call.record
  end

  test "confirmation made installments from the accepted proposals: the deposit due on confirmation and the balance on Jul 9, 2027 (CMN-08, CMN-12)" do
    installments = @rowan.client_charge.installments
    assert_equal [ [ 50_000, @rowan.confirmed_at.in_time_zone(@agency.default_timezone).to_date ], [ @rowan.client_charge.total_minor_units - 50_000, Date.new(2027, 7, 9) ] ],
      installments.map { |row| [ row.amount_minor_units, row.due_on ] }
    assert_equal @rowan.client_charge.total_minor_units, installments.sum(&:amount_minor_units)
  end

  test "an agency payment is applied, issues a gap-free receipt, and reduces the remainder (CMN-21, CMN-28, CMN-55)" do
    payment = pay!(amount: "500")
    assert_match(/\APAY-\d{5}\z/, payment.payment_reference)
    assert_match(/\ARCP-\d{5}\z/, payment.receipt.receipt_number)
    assert_equal [ { "booking_reference" => @rowan.booking_reference, "installment" => @rowan.client_charge.installments.first.description,
                     "due_on" => @rowan.client_charge.installments.first.due_on.iso8601, "amount_minor_units" => 50_000 } ], payment.receipt.applied
    charge = @rowan.client_charge.reload
    assert_equal [ 50_000, 50_000, 0 ], [ charge.paid_minor_units, charge.paid_minor_units("agency"), charge.paid_minor_units("supplier") ]
    assert_equal charge.total_minor_units - 50_000, charge.remainder_minor_units
    second = pay!(amount: "10", applications: [])
    assert_equal payment.receipt.receipt_number.succ, second.receipt.receipt_number
  end

  test "a supplier payment gets no receipt and isn't agency cash (CMN-29, SMN-27)" do
    alpha = @alpha.arrangements.fetch(:cruise).supplier
    payment = pay!(amount: "500", route: "supplier", supplier: alpha)
    assert_nil payment.receipt
    assert_equal [ 0, 50_000 ], [ @rowan.client_charge.reload.paid_minor_units("agency"), @rowan.client_charge.paid_minor_units("supplier") ]
    other = Supplier.where(agency: @agency).where.not(id: @alpha.departure.supplier_arrangements.map(&:supplier_id)).first || CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Elsewhere Co" }, categories: [ "cruise_line" ]).call.record
    error = assert_raises(AgencyCommand::Error) { pay!(amount: "1", applications: [], route: "supplier", supplier: other) }
    assert_match(/arrangement on this Departure/, error.message)
  end

  test "what isn't applied is credit, applied later to an installment (CMN-23, CMN-24)" do
    payment = pay!(amount: "800", applications: [])
    assert_equal 80_000, payment.credit_minor_units
    deposit = @rowan.client_charge.installments.first
    ApplyClientCredit.new(agency: @agency, actor: @admin, trip: @trip, applications: [ { installment_id: deposit.id, amount: "500" } ]).call
    assert_equal [ 30_000, 0 ], [ payment.reload.credit_minor_units, deposit.reload.open_minor_units ]
    error = assert_raises(AgencyCommand::Error) do
      ApplyClientCredit.new(agency: @agency, actor: @admin, trip: @trip, applications: [ { installment_id: @rowan.client_charge.installments.second.id, amount: "400" } ]).call
    end
    assert_match(/\$300\.00 of credit/, error.message)
  end

  test "a payment can't be applied beyond what an installment has open, or beyond itself" do
    deposit = @rowan.client_charge.installments.first
    error = assert_raises(AgencyCommand::Error) { pay!(amount: "600", applications: [ { installment_id: deposit.id, amount: "600" } ]) }
    assert_match(/\$500\.00 open/, error.message)
    error = assert_raises(AgencyCommand::Error) { pay!(amount: "100", applications: [ { installment_id: deposit.id, amount: "200" } ]) }
    assert_match(/no more than the payment/, error.message)
  end

  test "a reversal reopens what the payment settled and keeps both records; the receipt stays (CMN-27)" do
    payment = pay!(amount: "500")
    ReverseClientPayment.new(agency: @agency, actor: @admin, payment:, reason: "Check returned unpaid").call
    payment.reload
    assert payment.reversed?
    assert_equal [ 0, 0 ], [ payment.applied_minor_units, payment.credit_minor_units ]
    assert_equal 50_000, @rowan.client_charge.installments.first.reload.open_minor_units
    assert payment.receipt.present?
    assert_raises(AgencyCommand::Error) { ReverseClientPayment.new(agency: @agency, actor: @admin, payment:, reason: "Again").call }
  end

  test "only Financial records records money (CMN-19)" do
    error = assert_raises(AgencyCommand::Error) { pay!(amount: "500", actor: agency_users(:harbor_staff)) }
    assert_equal :unauthorized, error.code
  end

  test "payments, applications, reversals and receipts are append-only in PostgreSQL" do
    payment = pay!(amount: "500")
    [ [ ClientPayment, payment.id, { amount_minor_units: 1 } ], [ Receipt, payment.receipt.id, { amount_minor_units: 1 } ],
      [ ClientPaymentApplication, payment.applications.first.id, { amount_minor_units: 1 } ] ].each do |model, id, change|
      assert_raises(ActiveRecord::StatementInvalid) { model.transaction(requires_new: true) { model.where(id:).update_all(change) } }
    end
  end

  test "the backfill gives a booking confirmed before step 8 its installments, once (D-94 (2))" do
    booking = @alpha.bookings.fetch("BK-104")
    expected = booking.client_charge.installments.map { |row| [ row.description, row.amount_minor_units, row.due_on ] }
    # As if confirmed before installments existed; the test's transaction rolls this back.
    connection = ActiveRecord::Base.connection
    connection.execute("ALTER TABLE installments DISABLE TRIGGER installments_reject_mutation")
    Installment.where(client_charge: booking.client_charge).delete_all
    connection.execute("ALTER TABLE installments ENABLE TRIGGER installments_reject_mutation")

    assert_equal :created, CreateBookingInstallments.new(agency: @agency, booking:).call.status
    assert_equal expected, booking.client_charge.installments.reload.map { |row| [ row.description, row.amount_minor_units, row.due_on ] }
    assert_equal :noop, CreateBookingInstallments.new(agency: @agency, booking:).call.status
  end
end
