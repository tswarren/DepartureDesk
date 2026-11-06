class TaskReopeningsController < ApplicationController
  include TaskAccess

  before_action :require_task_use!
  before_action :set_task

  def create
    transition_task("Task reopened.") do
      ReopenTask.new(agency: Current.agency, actor: Current.agency_user, task: @task, lock_version: task_lock_version).call
    end
  end
end
