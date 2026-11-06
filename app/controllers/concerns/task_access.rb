# Tasks load through Current.agency, so another agency's task is not found.
# A refused transition re-renders the task page with the reason.
module TaskAccess
  extend ActiveSupport::Concern

  private

  def require_task_use!
    require_permission!(:use_tasks)
  end

  def set_task
    @task = Current.agency.tasks.includes(:departure, :owner, supplier_deadline: { supplier_arrangement: :supplier }).find(params[:task_id] || params[:id])
  end

  def transition_task(notice)
    yield
    redirect_to task_path(@task), notice:
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @transition_error = error.message
    @task.reload
    render "tasks/show", status: :unprocessable_entity
  end

  def task_lock_version = params[:lock_version]
end
