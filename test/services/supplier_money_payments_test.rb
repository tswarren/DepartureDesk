require "test_helper"

# Step 8b: supplier payments, their applications and reversals, task
# settlement, the arrangement balance basis and commission confirmation
# (SMN-04, SMN-06, SMN-17 to SMN-19, SMN-22, SMN-23, SMN-33; D-96, D-97).
class SupplierMoneyPaymentsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2027, 1, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @alpha = AlphaFixture.load!(agency: @agency, actor: @admin, bookings: :confirmed)
    set_clock Time.utc(2027, 2, 3, 15)
    @departure = @alpha.departure
    @cruise = @alpha.arrangements.fetch(:cruise)
    @alpha_cruises = @cruise.supplier
  end

  def amounts = @cruise.amounts_due.reload.includes(:payment_applications)

  def pay!(amount, applications: nil, actor: @admin)
    rows = applications || amounts.by_due.map { |due| { amount_due_id: due.id, amount: MoneyInput.display(due.amount_minor_units, "USD").delete(",") } }
    RecordSupplierPayment.new(agency: @agency, actor:, departure: @departure, supplier: @alpha_cruises, applications: rows, attributes: {
      payee_account_id: @cruise.payee_account_id, paid_on: "2027-02-03", amount:, payment_method: "bank_transfer", bank_reference: "Wire 0203"
    }).call.record
  end

  test "paying Alpha its amounts due settles them, changes no cost or capacity, and completes the settled tasks (D10, SMN-17, SMN-19)" do
    assert_equal 295_000, amounts.sum(&:amount_minor_units), "$1,600 and $450 for each of three cabins"
    cost = @cruise.cost_lines.reload.map { |line| [ line.id, line.amount_minor_units ] }
    capacity = [ CapacityEvent.count, InventoryAllocation.count ]
    deposit_task = @cruise.deadlines.find_by!(description: "Initial deposit, $50 per stateroom").task

    payment = pay!("2950")
    assert_match(/\ASPY-\d{4}\z/, payment.payment_reference)
    assert(amounts.all? { |due| due.paid_status == "paid" })
    assert_equal cost, @cruise.cost_lines.reload.map { |line| [ line.id, line.amount_minor_units ] }, "a deposit is never added to cost (SMN-03)"
    assert_equal capacity, [ CapacityEvent.count, InventoryAllocation.count ], "no payment changes capacity (D-92)"
    assert deposit_task.reload.completed?, "the initial deposit line can post no more, so its task completes"
    full = @cruise.deadlines.find_by!(description: "Full deposit and names for cabins not yet named").task
    assert full.reload.active?, "the full deposit line still posts for unsold cabins on Mar 1, 2027"
  end

  test "what isn't applied stays unapplied and is applied later; payments never cross suppliers (SMN-20, SMN-22)" do
    payment = pay!("1000", applications: [])
    assert_equal 100_000, payment.unapplied_minor_units
    first = amounts.by_due.first
    ApplySupplierPayment.new(agency: @agency, actor: @admin, departure: @departure, supplier: @alpha_cruises,
      applications: [ { amount_due_id: first.id, amount: "1000" } ]).call
    assert_equal [ 0, "part_paid" ], [ payment.reload.unapplied_minor_units, first.reload.paid_status ]

    hotel_amount = AmountDue.create!(agency: @agency, supplier_arrangement: @alpha.arrangements.fetch(:hotel), description: "Resort fee", amount_minor_units: 3_500,
      currency: "USD", due_on: Date.new(2027, 2, 1), posted_at: Clock.current.now, posted_by: @admin)
    error = assert_raises(AgencyCommand::Error) { pay!("35", applications: [ { amount_due_id: hotel_amount.id, amount: "35" } ]) }
    assert_match(/this supplier's/, error.message)
  end

  test "a reversal reopens what the payment settled and keeps both records (SMN-23)" do
    payment = pay!("2950")
    ReverseSupplierPayment.new(agency: @agency, actor: @admin, payment:, reason: "Wire returned by the bank").call
    assert payment.reload.reversed?
    assert(amounts.all? { |due| due.paid_status == "unpaid" })
    assert_raises(ActiveRecord::StatementInvalid) { SupplierPayment.transaction(requires_new: true) { SupplierPayment.where(id: payment.id).update_all(amount_minor_units: 1) } }
  end

  test "only Financial records records a supplier payment (SMN-18)" do
    error = assert_raises(AgencyCommand::Error) { pay!("100", applications: [], actor: agency_users(:harbor_staff)) }
    assert_equal :unauthorized, error.code
  end

  test "the arrangement balance posts the booked cabins' cost less their deposits once unsold cabins are released with their deposits kept (D-96, D-97)" do
    set_clock Time.utc(2027, 7, 15, 15)
    sweep = -> { PostArrangementAmountsDueJob.perform_now(agency_id: @agency.id, arrangement_id: @cruise.id) }
    sweep.call
    held = @cruise.inventory_groups.flat_map(&:unit_shells).select { |shell| shell.inventory_allocations.reject(&:state_released?).any? }
    unsold = @cruise.inventory_groups.flat_map(&:unit_shells) - held
    assert_equal 29, unsold.size
    unsold.each do |shell|
      RecordSupplierRelease.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise, group: shell.inventory_group,
        unit_shell_id: shell.id, quantity: 1, evidence_note: "Released to Alpha on Jul 15, 2027 (D-97)", idempotency_key: "release-#{shell.id}").call
    end
    SaveCostLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @cruise.reload, attributes: {
      description: "Deposits Alpha keeps on released cabins", scope: "unit_shells", unit_shell_ids: unsold.map(&:id), basis: "per_unit", rate: "500", stage: "committed"
    }).call

    set_clock Time.utc(2027, 8, 1, 15)
    sweep.call
    final = @cruise.amounts_due.reload.find_by!(description: "Final payment")
    assert_equal 2_385_000, final.amount_minor_units, "$25,350 + $14,500 − $16,000"
  end

  test "confirming a commission records the supplier's amount and ends overrides (SMN-33)" do
    booking = @alpha.bookings.fetch("BK-101")
    commission = booking.expected_commissions.sole
    ConfirmExpectedCommission.new(agency: @agency, actor: @admin, booking:, commission:, amount: "1100").call
    assert_equal [ "confirmed", 110_000 ], commission.reload.values_at(:status, :amount_minor_units)
    error = assert_raises(AgencyCommand::Error) { OverrideBookingSupplierCost.new(agency: @agency, actor: @admin, booking:, commission:, amount: "1").call }
    assert_match(/Only an expected commission/, error.message)
  end
end
