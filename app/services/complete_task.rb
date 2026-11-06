# Open or In progress to Completed, with a note of the action taken
# (OPS-03). Completing a task changes no other record.
class CompleteTask < AgencyCommand
  include TaskCommandSupport

  def initialize(agency:, actor:, task:, note:, lock_version:)
    @agency = agency
    @actor = actor
    @task = task
    @note = note
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:use_tasks)
    note = normalize_note(@note, "a completion note")

    ActiveRecord::Base.transaction do
      task = lock_task!(:use_tasks)
      ensure_task_status!(task, Task::ACTIVE_STATUSES, "Only an open or in-progress task can be completed.")
      task.update!(status: "completed", completion_note: note, completed_at: Clock.current.now)
      audit_task!(task, "departure.task_completed", "note" => note)
      Result.new(status: :updated, record: task)
    end
  end
end
