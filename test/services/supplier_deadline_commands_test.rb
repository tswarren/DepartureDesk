require "test_helper"

# SUP-22 to SUP-25, SET-10, OPS-04, OPS-12.
class SupplierDeadlineCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @agency = agencies(:harbor)
    @agency.update_columns(default_timezone: "America/New_York")
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Deadlines", operating_currency: "USD", time_zone: "America/Chicago" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Deadline Cruises" }, categories: [ "cruise_line" ]).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
  end

  test "a date-only deadline resolves to 11:59 p.m. agency time and keeps its local date and zone (SET-10)" do
    deadline = record!(deadline_type: "deposit_payment", description: "Deposit", due_on: "2026-11-01").record
    assert_equal Time.utc(2026, 11, 2, 4, 59), deadline.resolved_at
    assert_equal Date.new(2026, 11, 1), deadline.due_on
    assert_nil deadline.due_at_time
    assert_equal "America/New_York", deadline.time_zone

    @agency.update_columns(default_timezone: "Europe/London")
    assert_equal Time.utc(2026, 11, 2, 4, 59), deadline.reload.resolved_at, "the stored instant is not recalculated"
  end

  test "a timed deadline keeps the supplier's stated time and zone, defaulting to the Departure's (SUP-24)" do
    stated = record!(deadline_type: "final_count", description: "Final count", due_on: "2027-10-22", due_at_time: "17:00", time_zone: "America/Los_Angeles").record
    assert_equal Time.utc(2027, 10, 23, 0, 0), stated.resolved_at
    assert_equal "17:00", stated.due_at_time.strftime("%H:%M")

    defaulted = record!(deadline_type: "rooming_list", description: "Rooming list", due_on: "2027-10-01", due_at_time: "09:30").record
    assert_equal "America/Chicago", defaulted.time_zone
    assert_equal Time.utc(2027, 10, 1, 14, 30), defaulted.resolved_at

    assert_match(/hours and minutes/, assert_raises(AgencyCommand::Error) { record!(deadline_type: "other", description: "X", due_on: "2027-10-01", due_at_time: "5pm") }.message)
  end

  test "an actionable deadline creates its task for the default task owner, else the recorder (SUP-23, OPS-12)" do
    deadline = record!(deadline_type: "names_submission", description: "Names", due_on: "2027-03-01").record
    task = deadline.task
    assert task.open?
    assert_equal @admin, task.owner
    assert_equal "Deadline Cruises: Names", task.action
    assert_equal [ deadline.resolved_at, deadline.due_on, "America/New_York" ], [ task.due_at, task.due_on, task.due_time_zone ]
    assert_equal @departure, task.departure

    staff = agency_users(:harbor_staff)
    AddDepartureTeamMember.new(agency: @agency, actor: @admin, departure: @departure, agency_user_id: staff.id).call
    SetDepartureDefaultTaskOwner.new(agency: @agency, actor: @admin, departure: @departure.reload, agency_user_id: staff.id).call
    assert_equal staff, record!(deadline_type: "ticketing", description: "Tickets", due_on: "2027-09-01").record.task.owner

    RemoveDepartureTeamMember.new(agency: @agency, actor: @admin, departure: @departure.reload, agency_user_id: staff.id).call
    assert_equal @admin, record!(deadline_type: "other", description: "Other", due_on: "2027-09-02").record.task.owner
  end

  test "a cancellation-tier cutoff is informational by default and makes no task (SUP-22)" do
    deadline = record!(deadline_type: "cancellation_tier_cutoff", description: "50% penalty from here", due_on: "2027-06-01").record
    assert_not deadline.actionable
    assert_nil deadline.task
    assert_not record!(deadline_type: "deposit_payment", description: "Courtesy reminder", due_on: "2027-06-02", actionable: "0").record.task
  end

  test "changing a deadline moves its task's due date and keeps the history, without reopening a completed task (OPS-04)" do
    deadline = record!(deadline_type: "deposit_payment", description: "Deposit", due_on: "2026-11-01").record
    task = deadline.task
    CompleteTask.new(agency: @agency, actor: @admin, task:, note: "Paid by wire", lock_version: task.lock_version).call

    record!(deadline:, due_on: "2026-11-15")
    task.reload
    assert task.completed?
    assert_equal Date.new(2026, 11, 15), task.due_on
    updated = AuditEvent.where(subject_id: @arrangement.id, action: "supplier_arrangement.deadline_updated").sole
    assert_equal "2026-11-02T04:59:00Z", updated.details["previous_resolved_at"]
    assert AuditEvent.exists?(subject_id: @departure.id, action: "departure.task_due_changed")
  end

  test "marking a deadline informational waives its task; actionable again reopens the same task (OPS-04)" do
    deadline = record!(deadline_type: "option_release", description: "Release unsold", due_on: "2027-03-01").record
    task = deadline.task
    record!(deadline:, actionable: "0")
    assert task.reload.waived?
    assert_equal "Deadline marked informational.", task.waiver_reason

    record!(deadline:, actionable: "1")
    assert task.reload.open?
    assert_nil task.waiver_reason
    assert_equal 1, Task.where(supplier_deadline: deadline).count
  end

  test "discarding a Draft arrangement waives its open tasks with the reason arrangement discarded (SUP-23)" do
    open_task = record!(deadline_type: "deposit_payment", description: "Deposit", due_on: "2027-01-01").record.task
    done = record!(deadline_type: "names_submission", description: "Names", due_on: "2027-02-01").record.task
    CompleteTask.new(agency: @agency, actor: @admin, task: done, note: "Sent", lock_version: done.lock_version).call

    DiscardSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, lock_version: @arrangement.reload.lock_version).call
    assert_equal [ "waived", "arrangement discarded" ], open_task.reload.values_at(:status, :waiver_reason)
    assert done.reload.completed?

    refused = assert_raises(AgencyCommand::Error) { record!(deadline_type: "other", description: "Late", due_on: "2027-03-01") }
    assert_equal :invalid_state, refused.code
  end

  test "deadlines need Supplier arrangements; a group must be the arrangement's own" do
    refused = assert_raises(AgencyCommand::Error) do
      SaveSupplierDeadline.new(agency: @agency, actor: agency_users(:harbor_staff), departure: @departure, arrangement: @arrangement,
        attributes: { deadline_type: "other", description: "X", due_on: "2027-01-01" }).call
    end
    assert_equal :unauthorized, refused.code
    assert_match(/inventory groups/, assert_raises(AgencyCommand::Error) {
      record!(deadline_type: "other", description: "X", due_on: "2027-01-01", inventory_group_id: SecureRandom.uuid)
    }.message)
  end

  test "a deadline never touches inventory or money (SUP-25)" do
    group = SaveInventoryGroup.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, attributes: { label: "V01", service_category: "cruise" }).call.record
    deadline = record!(deadline_type: "option_release", description: "Release V01", due_on: "2026-11-01", inventory_group_id: group.id).record
    assert_equal group, deadline.inventory_group
    set_clock Time.utc(2026, 12, 1)
    assert deadline.task.reload.overdue?
    assert_empty group.capacity_events
  end

  private

  def record!(deadline: nil, **attributes)
    SaveSupplierDeadline.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement, deadline:,
      attributes:, lock_version: deadline&.reload&.lock_version).call
  end
end
