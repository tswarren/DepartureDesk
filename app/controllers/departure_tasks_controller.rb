# S-34: every task on the Departure, with its source, owner and status.
class DepartureTasksController < ApplicationController
  include DepartureAccess
  include TaskAccess

  before_action :require_task_use!
  before_action :set_departure

  def index
    @tasks = @departure.tasks.by_due.includes(:owner, supplier_deadline: { supplier_arrangement: :supplier })
  end
end
