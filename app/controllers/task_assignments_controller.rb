# Reassigning a task (S-34) needs Departure management.
class TaskAssignmentsController < ApplicationController
  include TaskAccess

  before_action :require_task_use!
  before_action -> { require_permission!(:reassign_tasks) }
  before_action :set_task

  def update
    transition_task("Task reassigned.") do
      ReassignTask.new(agency: Current.agency, actor: Current.agency_user, task: @task, owner_id: params[:owner_id], lock_version: task_lock_version).call
    end
  end
end
