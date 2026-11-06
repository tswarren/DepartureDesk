# Completed to Open when the same requirement becomes actionable again;
# the earlier history stays in the audit trail (OPS-04).
class ReopenTask < AgencyCommand
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
      ensure_task_status!(task, %w[completed], "Only a completed task can be reopened.")
      reopen_task!(task)
      Result.new(status: :updated, record: task)
    end
  end
end
