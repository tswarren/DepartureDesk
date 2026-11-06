# Gives an open or in-progress task to another Agency Admin or Staff user
# (S-34). Needs Departure management.
class ReassignTask < AgencyCommand
  include TaskCommandSupport

  def initialize(agency:, actor:, task:, owner_id:, lock_version:)
    @agency = agency
    @actor = actor
    @task = task
    @owner_id = owner_id
    @lock_version = lock_version
  end

  def call
    ensure_departure_actor!(:reassign_tasks)

    ActiveRecord::Base.transaction do
      task = lock_task!(:reassign_tasks)
      ensure_task_status!(task, Task::ACTIVE_STATUSES, "Only an open or in-progress task can be reassigned.")
      owner = resolve_agency_user!(@owner_id)
      raise Error.new("Choose who owns the task.", code: :invalid) if owner.nil?
      raise Error.new("Choose an active user.", code: :invalid) unless owner.active?
      return Result.new(status: :noop, record: task) if owner.id == task.owner_id

      previous_owner_id = task.owner_id
      task.update!(owner:)
      audit_task!(task, "departure.task_reassigned", "owner_id" => owner.id, "previous_owner_id" => previous_owner_id)
      Result.new(status: :updated, record: task)
    end
  end
end
