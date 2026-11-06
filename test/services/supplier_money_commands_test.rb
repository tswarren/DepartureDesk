require "test_helper"

# SMN-01 to SMN-06, SMN-08, SMN-10, SMN-11 to SMN-14, SMN-17, SUP-13, D-75, D-81.
class SupplierMoneyCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2026, 10, 15, 14)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Money", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Money Cruises" }, categories: [ "cruise_line" ]).call.record
    payee = SavePayeeAccount.new(agency: @agency, actor: @admin, supplier:, attributes: { name: "USD", currency: "USD" }).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id,
      attributes: { group_reference: "GRP", payee_account_id: payee.id }).call.record
    dates = { starts_on: "2027-11-06", ends_on: "2027-11-13", time_zone: "America/New_York" }
    @cabins = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { label: "V01", service_category: "cruise", quantity: "4", positions_per_unit: "3", **dates }).call.record
    @pool = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { label: "Seats", service_category: "air", representation: "capacity_pool", quantity: "2", **dates }).call.record
  end

  test "cost lines: fixed, per unit over named shells, per group, and a percentage that follows its base (SMN-02, D-75)" do
    confirm!
    shells = @cabins.reload.unit_shells.first(2)
    per_shell = save_cost!(scope: "unit_shells", unit_shell_ids: shells.map(&:id), basis: "per_unit", rate: "145", stage: "committed", description: "Firm rooms").record
    assert_equal [ 2, 29_000 ], [ per_shell.quantity, per_shell.amount_minor_units ], "the quantity defaults to the shells named"
    assert_equal shells.map(&:id).sort, per_shell.unit_shell_ids.sort

    group = save_cost!(scope: "inventory_group", inventory_group_id: @pool.id, basis: "per_person", rate: "100", quantity: "2", stage: "estimated", description: "Seats").record
    fee = save_cost!(scope: "arrangement", basis: "percentage", base_cost_line_id: group.id, percentage: "12.5", stage: "estimated", description: "Fee").record
    assert_equal 2_500, fee.amount_minor_units

    save_cost!(cost_line: group, scope: "inventory_group", inventory_group_id: @pool.id, basis: "per_person", rate: "100.03", quantity: "2", stage: "estimated", description: "Seats")
    assert_equal 2_501, fee.reload.amount_minor_units, "12.5% of 200.06 is 25.0075, rounded half up to 25.01"
    assert_equal :invalid, assert_raises(AgencyCommand::Error) {
      save_cost!(scope: "unit_shells", unit_shell_ids: [ SecureRandom.uuid ], basis: "fixed", rate: "1", stage: "committed", description: "X")
    }.code
  end

  test "confirmation records the Arrangement confirmed event and no cost (D-75, SMN-11)" do
    confirm!
    assert_equal [ "arrangement_confirmed" ], @arrangement.trigger_events.pluck(:event_type)
    assert_empty @arrangement.cost_lines
    assert_empty @arrangement.amounts_due
  end

  test "a fixed date posts at the start of that date in agency time, once" do
    confirm!
    schedule!(description: "Deposit", amount_kind: "fixed", amount: "1600", due_rule: "fixed_date", due_on: "2026-11-01")
    sweep_at(Time.find_zone("America/New_York").local(2026, 10, 31, 23, 59))
    assert_empty @arrangement.amounts_due.reload
    sweep_at(Time.find_zone("America/New_York").local(2026, 11, 1, 0, 1))
    amount = @arrangement.amounts_due.reload.sole
    assert_equal [ 160_000, Date.new(2026, 11, 1), "USD" ], [ amount.amount_minor_units, amount.due_on, amount.currency ]
    assert_equal SupplierAmountPosting::SYSTEM_ACTOR_IDENTIFIER, amount.posted_by_identifier
    sweep_at(Time.find_zone("America/New_York").local(2026, 11, 2))
    assert_equal 1, @arrangement.amounts_due.reload.size, "the sweep is idempotent"
  end

  test "an event posts at once, on the date it happened; a period after an event waits (SMN-13)" do
    confirm!
    on_event = schedule!(description: "On count", amount_kind: "fixed", amount: "100", due_rule: "event", trigger_type: "final_count_submitted").record
    later = schedule!(description: "After count", amount_kind: "fixed", amount: "50", due_rule: "event_plus_days", trigger_type: "final_count_submitted", days_after: "10").record

    record_event!("final_count_submitted", "2026-10-12")
    assert_equal Date.new(2026, 10, 12), on_event.amounts_due.sole.due_on, "a late-recorded event posts at once with its own date"
    assert_empty later.amounts_due
    sweep_at(Time.utc(2026, 10, 22, 14))
    assert_equal Date.new(2026, 10, 22), later.amounts_due.reload.sole.due_on
  end

  test "the earlier of an event and a date posts on whichever comes first (SMN-13)" do
    confirm!
    by_event = schedule!(description: "Payment", amount_kind: "fixed", amount: "1000", due_rule: "earlier_of", trigger_type: "final_count_submitted", due_on: "2027-10-22").record
    record_event!("final_count_submitted", "2026-10-14")
    assert_equal Date.new(2026, 10, 14), by_event.amounts_due.sole.due_on

    by_date = schedule!(description: "Invoice", amount_kind: "fixed", amount: "10", due_rule: "earlier_of", trigger_type: "supplier_invoice_received", due_on: "2026-12-01").record
    sweep_at(Time.utc(2026, 12, 1, 14))
    assert_equal Date.new(2026, 12, 1), by_date.amounts_due.reload.sole.due_on, "the date posts when the event never happens"
  end

  test "a per-shell line posts once per shell, skipping returned shells; a count line snapshots its count (SMN-06, SMN-10, SMN-14, D-81)" do
    confirm!
    returned = @cabins.reload.unit_shells.last
    RecordSupplierRelease.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, group: @cabins,
      unit_shell_id: returned.id, evidence_note: "Released", idempotency_key: SecureRandom.uuid).call

    per_shell = schedule!(description: "Full deposit", amount_kind: "per_shell", rate: "450", due_rule: "earlier_of",
      trigger_type: "client_booking_confirmed", due_on: "2027-03-01").record
    count = schedule!(description: "Initial deposit", amount_kind: "per_unit_count", rate: "50", due_rule: "fixed_date", due_on: "2026-11-01").record
    sweep_at(Time.utc(2027, 3, 1, 14))
    sweep_at(Time.utc(2027, 3, 2, 14))

    assert_equal 3, per_shell.amounts_due.size
    assert_not_includes per_shell.amounts_due.map(&:unit_shell_id), returned.id
    assert per_shell.amounts_due.all? { |amount| amount.amount_minor_units == 45_000 && amount.due_on == Date.new(2027, 3, 1) }
    assert_equal [ 3, 15_000 ], count.amounts_due.sole.values_at(:quantity, :amount_minor_units)

    assert_raises(ActiveRecord::RecordNotUnique) do
      AmountDue.transaction(requires_new: true) do
        AmountDue.insert_all!([ per_shell.amounts_due.first.attributes.except("id").merge("posted_at" => Time.current) ])
      end
    end
  end

  test "a percentage of a cost line is snapshotted when posted; the cost line is then fixed (SMN-06)" do
    confirm!
    cost = save_cost!(scope: "arrangement", basis: "fixed", rate: "1000", stage: "committed", description: "Resource").record
    schedule!(description: "Balance", cost_line_id: cost.id, amount_kind: "percentage_of_cost_line", percentage: "100", due_rule: "fixed_date", due_on: "2026-10-15")
    amount = @arrangement.amounts_due.reload.sole
    assert_equal [ 100_000, BigDecimal("100"), 100_000 ], amount.values_at(:amount_minor_units, :percentage, :base_minor_units)
    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) {
      save_cost!(cost_line: cost, scope: "arrangement", basis: "fixed", rate: "900", stage: "committed", description: "Resource")
    }.code
  end

  test "a Draft arrangement posts nothing" do
    schedule!(description: "Deposit", amount_kind: "fixed", amount: "10", due_rule: "fixed_date", due_on: "2026-10-01")
    PostArrangementAmountsDue.new(agency: @agency, arrangement: @arrangement).call
    assert_empty @arrangement.amounts_due.reload
  end

  test "payment tasks: a deadline's task is reused; a dated line gets its own; an event-only line gets one when it posts (SMN-17)" do
    confirm!
    deadline = SaveSupplierDeadline.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { deadline_type: "deposit_payment", description: "Deposit", due_on: "2026-11-01" }).call.record
    with_deadline = schedule!(description: "Deposit", amount_kind: "fixed", amount: "1", due_rule: "fixed_date", due_on: "2026-11-01", supplier_deadline_id: deadline.id).record
    assert_nil with_deadline.task

    dated = schedule!(description: "Balance", amount_kind: "fixed", amount: "1", due_rule: "fixed_date", due_on: "2027-08-01").record
    assert_equal [ Date.new(2027, 8, 1), "Money Cruises: Balance", @admin ], dated.task.values_at(:due_on, :action, :owner)

    on_event = schedule!(description: "On invoice", amount_kind: "fixed", amount: "1", due_rule: "event", trigger_type: "supplier_invoice_received").record
    assert_nil on_event.task
    record_event!("supplier_invoice_received", "2026-10-15")
    assert_equal Date.new(2026, 10, 15), on_event.reload.task.due_on
  end

  test "completing a final-count task records the event and posts its payment, and needs Supplier arrangements (SMN-12)" do
    confirm!
    deadline = SaveSupplierDeadline.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { deadline_type: "final_count", description: "Final count", due_on: "2027-10-22" }).call.record
    payment = schedule!(description: "Resource", amount_kind: "fixed", amount: "1000", due_rule: "earlier_of",
      trigger_type: "final_count_submitted", due_on: "2027-10-22").record
    task = deadline.task

    refused = assert_raises(AgencyCommand::Error) do
      CompleteTask.new(agency: @agency, actor: agency_users(:harbor_baseline_staff), task:, note: "Sent", lock_version: task.lock_version, event_occurred_on: "2026-10-15").call
    end
    assert_equal :unauthorized, refused.code

    CompleteTask.new(agency: @agency, actor: @admin, task:, note: "Count of 9 sent", lock_version: task.lock_version, event_occurred_on: "2026-10-15", event_count: "9").call
    assert task.reload.completed?
    event = @arrangement.trigger_events.find_by!(event_type: "final_count_submitted")
    assert_equal [ Date.new(2026, 10, 15), 9 ], [ event.occurred_on, event.count ]
    assert_equal event, payment.amounts_due.sole.trigger_event
  end

  test "a direct amount due needs Supplier arrangements or Financial records and gets its own task (SMN-05)" do
    confirm!
    staff = agency_users(:harbor_baseline_staff)
    assert_equal :unauthorized, assert_raises(AgencyCommand::Error) { direct!(staff) }.code

    UserPermission.create!(agency: @agency, agency_user: staff, permission: "financial_records")
    amount = direct!(staff.reload).record
    assert amount.direct?
    assert_equal [ 25_000, Date.new(2026, 12, 1) ], [ amount.amount_minor_units, amount.due_on ]
    assert_equal "Money Cruises: Port fee", amount.task.action
  end

  test "trigger events and amounts due are append-only in the database" do
    confirm!
    event = @arrangement.trigger_events.sole
    assert_raises(ActiveRecord::StatementInvalid) { TriggerEvent.transaction(requires_new: true) { TriggerEvent.where(id: event.id).update_all(count: 1) } }
    amount = direct!(@admin).record
    assert_raises(ActiveRecord::StatementInvalid) { AmountDue.transaction(requires_new: true) { AmountDue.where(id: amount.id).delete_all } }
  end

  test "the database refuses a missing quantity, amount, percentage or day count, not only a wrong one" do
    confirm!
    cost = save_cost!(scope: "arrangement", basis: "per_unit", rate: "10", quantity: "2", stage: "estimated", description: "Seats").record
    line = schedule!(description: "Later", amount_kind: "fixed", amount: "5", due_rule: "event_plus_days", trigger_type: "other", days_after: "3").record
    {
      -> { CostLine.where(id: cost.id).update_all(quantity: nil) } => "a per-unit cost line without a quantity",
      -> { ScheduleLine.where(id: line.id).update_all(days_after: nil) } => "a days-after rule without its days",
      -> { ScheduleLine.where(id: line.id).update_all(amount_minor_units: nil) } => "a fixed line without its amount"
    }.each do |change, label|
      assert_raises(ActiveRecord::StatementInvalid, label) { CostLine.transaction(requires_new: true) { change.call } }
    end
  end

  test "supplier money needs Supplier arrangements, and other agencies' records are not found" do
    assert_equal :unauthorized, assert_raises(AgencyCommand::Error) {
      SaveCostLine.new(agency: @agency, actor: agency_users(:harbor_staff), departure: @departure, arrangement: @arrangement,
        attributes: { scope: "arrangement", basis: "fixed", rate: "1", stage: "estimated", description: "X" }).call
    }.code
    assert_raises(ActiveRecord::RecordNotFound) do
      SaveCostLine.new(agency: agencies(:cove), actor: agency_users(:cove_admin), departure: @departure, arrangement: @arrangement,
        attributes: { scope: "arrangement", basis: "fixed", rate: "1", stage: "estimated", description: "X" }).call
    end
  end

  private

  def confirm!
    ConfirmSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      confirmed_on: "2026-10-01", lock_version: @arrangement.reload.lock_version).call
    @arrangement.reload
  end

  def save_cost!(cost_line: nil, **attributes)
    SaveCostLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, cost_line:,
      attributes:, lock_version: cost_line&.reload&.lock_version).call
  end

  def schedule!(**attributes)
    SaveScheduleLine.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, attributes:).call
  end

  def record_event!(type, occurred_on)
    RecordTriggerEvent.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, event_type: type, occurred_on:).call
  end

  def direct!(actor)
    RecordDirectAmountDue.new(agency: @agency, actor:, departure: @departure, arrangement: @arrangement,
      attributes: { description: "Port fee", amount: "250", due_on: "2026-12-01" }).call
  end

  def sweep_at(time)
    set_clock time
    PostArrangementAmountsDue.new(agency: @agency, arrangement: @arrangement).call
  end
end
