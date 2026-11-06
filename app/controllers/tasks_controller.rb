# S-33 My tasks: the signed-in user's open and in-progress tasks by due
# instant, and each task's page with its actions and history.
class TasksController < ApplicationController
  include TaskAccess

  before_action :require_task_use!
  before_action :set_task, only: :show

  def index
    @tasks = Current.agency.tasks.active.where(owner: Current.agency_user).by_due.includes(:departure)
  end

  def show
  end
end
