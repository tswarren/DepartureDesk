# Open or In progress to Completed, with a note of the action taken
# (OPS-03). Completing a task changes no other record, except that a task
# whose deadline maps to a trigger event records that event and posts what
# it makes due (SMN-12); that needs Supplier arrangements.
class CompleteTask < AgencyCommand
  include TriggerEventRecording

  def initialize(agency:, actor:, task:, note:, lock_version:, event_occurred_on: nil, event_count: nil)
    @agency = agency
    @actor = actor
    @task = task
    @note = note
    @lock_version = lock_version
    @event_occurred_on = event_occurred_on
    @event_count = event_count
  end

  def call
    ensure_departure_actor!(:use_tasks)
    note = normalize_note(@note, "a completion note")
    event_type = @agency.tasks.find(@task.id).records_event_type
    if event_type && !@actor.permitted?(:manage_arrangements)
      raise Error.new("Completing this task records a supplier submission, which needs the Supplier arrangements permission.", code: :unauthorized)
    end

    ActiveRecord::Base.transaction do
      if event_type
        task, departure, arrangement = lock_event_task!
        ensure_task_status!(task, Task::ACTIVE_STATUSES, "Only an open or in-progress task can be completed.")
        record_trigger_event!(departure, arrangement, event_type:, occurred_on: @event_occurred_on, count: @event_count)
      else
        task = lock_task!(:use_tasks)
        ensure_task_status!(task, Task::ACTIVE_STATUSES, "Only an open or in-progress task can be completed.")
      end
      task.update!(status: "completed", completion_note: note, completed_at: Clock.current.now)
      audit_task!(task, "departure.task_completed", { "note" => note, "event_type" => event_type }.compact)
      Result.new(status: :updated, record: task)
    end
  end

  private

  # Lock order: agency, Departure, arrangement, then the task.
  def lock_event_task!
    lock_authorized_agency!(:manage_arrangements)
    found = @agency.tasks.find(@task.id)
    departure = @agency.departures.lock.find(found.departure_id)
    arrangement = departure.supplier_arrangements.lock.find(found.supplier_deadline.supplier_arrangement_id)
    task = departure.tasks.lock.find(found.id).tap { |locked| ensure_current_task_version!(locked) }
    [ task, departure, arrangement ]
  end
end
