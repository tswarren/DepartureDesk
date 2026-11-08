require "test_helper"

# S-15, S-33, S-34: SUP-22 to SUP-24, OPS-02 to OPS-04, ACC-30.
class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    set_clock Time.utc(2026, 11, 10, 15)
    @agency = agencies(:harbor)
    @admin = agency_users(:harbor_admin)
    @departure = CreateDeparture.new(agency: @agency, actor: @admin, attributes: { name: "Task Routes", operating_currency: "USD", time_zone: "America/New_York" }).call.record
    supplier = CreateSupplier.new(agency: @agency, actor: @admin, kind: "organization", names: { display_name: "Route Cruises" }, categories: [ "cruise_line" ]).call.record
    @arrangement = CreateSupplierArrangement.new(agency: @agency, actor: @admin, departure: @departure, supplier_id: supplier.id).call.record
  end

  test "staff record a timed deadline on the arrangement page and see its task" do
    sign_in_as @admin
    post departure_arrangement_deadlines_path(@departure, @arrangement), params: { supplier_deadline: {
      deadline_type: "final_count", actionable: "", description: "Final count", due_on: "2027-10-22", due_at_time: "17:00", time_zone: "America/Los_Angeles"
    } }
    assert_redirected_to departure_arrangement_path(@departure, @arrangement, anchor: "deadlines")
    deadline = @arrangement.deadlines.sole
    assert deadline.actionable

    get departure_arrangement_path(@departure, @arrangement)
    assert_select "#deadlines th[scope=row]", text: /Final count/
    assert_select "#deadlines td", text: /Oct 22, 2027, 5:00 PM America\/Los_Angeles/
    assert_select "#deadlines td", text: /Oct 22, 2027, 8:00 PM agency time/
    assert_select "#deadlines a[href='#{task_path(deadline.task)}']"

    get edit_departure_arrangement_deadline_path(@departure, @arrangement, deadline)
    patch departure_arrangement_deadline_path(@departure, @arrangement, deadline), params: { supplier_deadline: {
      deadline_type: "final_count", actionable: "true", description: "Final count", due_on: "2027-10-20", due_at_time: "", time_zone: "", lock_version: deadline.lock_version
    } }
    assert_equal Date.new(2027, 10, 20), deadline.task.reload.due_on
  end

  test "the deadline form asks what is due and by when, and a blank name takes what is due (SUP-22)" do
    sign_in_as @admin
    get new_departure_arrangement_deadline_path(@departure, @arrangement)
    assert_select "label", text: "What is due"
    assert_select "label", text: "By"
    assert_select "input[type=checkbox][name='supplier_deadline[actionable]'][checked]"
    assert_select "[role=status]", text: "Choose what is due and when."

    post departure_arrangement_deadlines_path(@departure, @arrangement), params: { supplier_deadline: {
      deadline_type: "cancellation_tier_cutoff", actionable: "false", description: "", due_on: "2027-07-09"
    } }
    deadline = @arrangement.deadlines.sole
    assert_equal [ "Cancellation-tier cutoff", false ], [ deadline.description, deadline.actionable ]
    assert_nil deadline.task
  end

  test "an invalid deadline re-renders the form" do
    sign_in_as @admin
    post departure_arrangement_deadlines_path(@departure, @arrangement), params: { supplier_deadline: { deadline_type: "other", description: "No date", due_on: "" } }
    assert_response :unprocessable_entity
    assert_select "#form-error-summary", text: /due date/
  end

  test "My tasks lists the user's active tasks; a task is started, refused without a note, and completed" do
    task = record_task!
    sign_in_as @admin
    get tasks_path
    assert_select "h1", text: "My tasks"
    assert_select "tbody th a", text: "Route Cruises: Deposit"

    post task_start_path(task), params: { lock_version: task.lock_version }
    assert task.reload.in_progress?
    post task_completion_path(task), params: { lock_version: task.lock_version, completion_note: "" }
    assert_response :unprocessable_entity
    assert_select ".dd-alert--danger", text: "Enter a completion note."
    post task_completion_path(task), params: { lock_version: task.lock_version, completion_note: "Wired" }
    assert_redirected_to task_path(task)
    assert task.reload.completed?

    get task_path(task)
    assert_select "#task-history td", text: /Completed · Wired/
    get tasks_path
    assert_select "tbody", count: 0
  end

  test "baseline staff see the Departure's tasks but cannot reassign; Departure management can" do
    task = record_task!
    sign_in_as agency_users(:harbor_baseline_staff)
    get departure_tasks_path(@departure)
    assert_select "nav[aria-label='Departure sections'] a[aria-current=page]", text: "Tasks"
    assert_select "td", text: "Deposit or payment · Route Cruises"
    get task_path(task)
    assert_select "select#owner_id", count: 0
    patch task_assignment_path(task), params: { lock_version: task.lock_version, owner_id: agency_users(:harbor_baseline_staff).id }
    assert_redirected_to root_path
    assert_equal @admin, task.reload.owner

    sign_in_as agency_users(:harbor_staff)
    patch task_assignment_path(task), params: { lock_version: task.lock_version, owner_id: agency_users(:harbor_baseline_staff).id }
    assert_equal agency_users(:harbor_baseline_staff), task.reload.owner
  end

  test "other agencies get not found" do
    task = record_task!
    sign_in_as agency_users(:cove_admin)
    get task_path(task)
    assert_response :not_found
    post task_start_path(task), params: { lock_version: task.lock_version }
    assert_response :not_found
    get departure_tasks_path(@departure)
    assert_response :not_found
  end

  private

  def record_task!
    SaveSupplierDeadline.new(agency: @agency, actor: @admin, departure: @departure, arrangement: @arrangement,
      attributes: { deadline_type: "deposit_payment", description: "Deposit", due_on: "2027-01-15" }).call.record.task
  end
end
