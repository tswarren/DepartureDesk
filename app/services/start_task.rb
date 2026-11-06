# Open to In progress: the owner has started (task lifecycle, OPS-03).
class StartTask < AgencyCommand
  include TaskCommandSupport

  def initialize(agency:, actor:, task:, lock_version:)
    @agency = agency
    @actor = actor
    @task = task
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:use_tasks)

    ActiveRecord::Base.transaction do
      task = lock_task!(:use_tasks)
      ensure_task_status!(task, %w[open], "Only an open task can be started.")
      task.update!(status: "in_progress")
      audit_task!(task, "departure.task_started")
      Result.new(status: :updated, record: task)
    end
  end
end
