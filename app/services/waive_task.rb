# Open or In progress to Waived, with the reason the deadline no longer
# applies (OPS-03).
class WaiveTask < AgencyCommand
  include TaskCommandSupport

  def initialize(agency:, actor:, task:, reason:, lock_version:)
    @agency = agency
    @actor = actor
    @task = task
    @reason = reason
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:use_tasks)
    reason = normalize_note(@reason, "a reason")

    ActiveRecord::Base.transaction do
      task = lock_task!(:use_tasks)
      ensure_task_status!(task, Task::ACTIVE_STATUSES, "Only an open or in-progress task can be waived.")
      waive_task!(task, reason)
      Result.new(status: :updated, record: task)
    end
  end
end
