require "test_helper"

# OPS-01 to OPS-04: the task lifecycle for individual owners.
class TaskCommandsTest < ActiveSupport::TestCase
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Tasks", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Task Supplier" }, categories: [ "cruise_line" ]).call.record
    arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
    @deadline = SaveSupplierDeadline.new(agency: @agency, actor: @admin, departure: @departure, arrangement:,
      attributes: { deadline_type: "deposit_payment", description: "Deposit", due_on: "2026-11-01" }).call.record
    @task = @deadline.task
  end

  test "baseline staff start, complete with a note, and reopen a completed task, each audited" do
    staff = agency_users(:harbor_baseline_staff)
    StartTask.new(agency: @agency, actor: staff, task: @task, lock_version: @task.lock_version).call
    assert @task.reload.in_progress?

    blank = assert_raises(AgencyCommand::Error) { complete!(staff, "  ") }
    assert_equal "Enter a completion note.", blank.message
    complete!(staff, "Deposit wired, ref 5512")
    @task.reload
    assert @task.completed?
    assert_equal Time.utc(2026, 11, 10, 15), @task.completed_at
    assert_equal "deposit_payment", @deadline.reload.deadline_type, "completing changes no other record (OPS-03)"

    ReopenTask.new(agency: @agency, actor: staff, task: @task, lock_version: @task.lock_version).call
    assert @task.reload.open?
    assert_nil @task.completion_note
    assert_equal %w[departure.task_created departure.task_started departure.task_completed departure.task_reopened],
      AuditEvent.where(subject_id: @departure.id).where("action LIKE 'departure.task_%'").order(:created_at).pluck(:action)
    completed = AuditEvent.find_by!(subject_id: @departure.id, action: "departure.task_completed")
    assert_equal "Deposit wired, ref 5512", completed.details["note"], "the earlier note stays in the history"
  end

  test "waiving needs a reason; finished tasks refuse further transitions" do
    assert_equal "Enter a reason.", assert_raises(AgencyCommand::Error) { waive!("") }.message
    waive!("Supplier extended the option")
    assert @task.reload.waived?

    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) { complete!(@admin, "Late") }.code
    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) { StartTask.new(agency: @agency, actor: @admin, task: @task, lock_version: @task.lock_version).call }.code
    assert_equal :invalid_state, assert_raises(AgencyCommand::Error) { ReopenTask.new(agency: @agency, actor: @admin, task: @task, lock_version: @task.lock_version).call }.code
  end

  test "a stale transition is refused" do
    stale = @task.lock_version
    StartTask.new(agency: @agency, actor: @admin, task: @task, lock_version: stale).call
    assert_equal :conflict, assert_raises(AgencyCommand::Error) { CompleteTask.new(agency: @agency, actor: @admin, task: @task, note: "x", lock_version: stale).call }.code
  end

  test "reassigning needs Departure management and an active Agency Admin or Staff owner" do
    baseline = agency_users(:harbor_baseline_staff)
    refused = assert_raises(AgencyCommand::Error) { reassign!(baseline, baseline.id) }
    assert_equal :unauthorized, refused.code

    reassign!(agency_users(:harbor_staff), baseline.id)
    assert_equal baseline, @task.reload.owner
    assert_equal :not_found, assert_raises(AgencyCommand::Error) { reassign!(@admin, agency_users(:cove_admin).id) }.code
  end

  test "overdue is derived from the due instant and the clock, and only while the task is active" do
    set_clock Time.utc(2026, 11, 2, 4, 58)
    assert_not @task.overdue?
    set_clock Time.utc(2026, 11, 2, 5, 0)
    assert @task.overdue?
    complete!(@admin, "Done")
    assert_not @task.reload.overdue?
  end

  test "the database requires a note to complete, a reason to waive, and a source record for a deadline task" do
    assert_raises(ActiveRecord::StatementInvalid) do
      Task.transaction(requires_new: true) { Task.where(id: @task.id).update_all(status: "completed", completed_at: Time.current) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Task.transaction(requires_new: true) { Task.where(id: @task.id).update_all(status: "waived", waived_at: Time.current, waiver_reason: " ") }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Task.transaction(requires_new: true) { Task.where(id: @task.id).update_all(supplier_deadline_id: nil) }
    end
    assert_raises(ActiveRecord::StatementInvalid) do
      Task.transaction(requires_new: true) { Task.where(id: @task.id).update_all(owner_id: agency_users(:cove_admin).id) }
    end
  end

  test "other agencies get not found" do
    error = assert_raises(ActiveRecord::RecordNotFound) do
      StartTask.new(agency: agencies(:cove), actor: agency_users(:cove_admin), task: @task, lock_version: @task.lock_version).call
    end
    assert_match(/Task/, error.message)
  end

  private

  def complete!(actor, note)
    CompleteTask.new(agency: @agency, actor:, task: @task, note:, lock_version: @task.reload.lock_version).call
  end

  def waive!(reason)
    WaiveTask.new(agency: @agency, actor: @admin, task: @task, reason:, lock_version: @task.reload.lock_version).call
  end

  def reassign!(actor, owner_id)
    ReassignTask.new(agency: @agency, actor:, task: @task, owner_id:, lock_version: @task.reload.lock_version).call
  end
end
