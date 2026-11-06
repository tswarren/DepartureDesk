class TaskCompletionsController < ApplicationController
  include TaskAccess

  before_action :require_task_use!
  before_action :set_task

  def create
    transition_task("Task completed.") do
      CompleteTask.new(agency: Current.agency, actor: Current.agency_user, task: @task, note: params[:completion_note], lock_version: task_lock_version,
        event_occurred_on: params[:event_occurred_on], event_count: params[:event_count]).call
    end
  end
end
