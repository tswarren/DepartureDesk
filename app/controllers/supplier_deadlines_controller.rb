# S-15: record and change an arrangement's supplier deadlines.
class SupplierDeadlinesController < ApplicationController
  include ArrangementAccess

  FIELDS = %i[deadline_type actionable description due_on due_at_time time_zone inventory_group_id].freeze

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_deadline, only: %i[edit update]

  def new
    @deadline = @arrangement.deadlines.new(time_zone: @departure.time_zone)
  end

  def create
    result = SaveSupplierDeadline.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, attributes: deadline_params).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "deadlines"),
      notice: result.record.actionable ? "Deadline recorded, with a task." : "Deadline recorded as informational."
  rescue AgencyCommand::Error => error
    @deadline = @arrangement.deadlines.new(deadline_params.except(:actionable, :inventory_group_id))
    render_error(error, :new)
  end

  def edit
  end

  def update
    SaveSupplierDeadline.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, deadline: @deadline,
      attributes: deadline_params, lock_version: params.dig(:supplier_deadline, :lock_version)
    ).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "deadlines"), notice: "Deadline updated."
  rescue AgencyCommand::Error => error
    @deadline.assign_attributes(deadline_params.except(:actionable, :inventory_group_id))
    render_error(error, :edit)
  end

  private

  def set_deadline
    @deadline = @arrangement.deadlines.find(params[:id])
  end

  def deadline_params
    params.require(:supplier_deadline).permit(*FIELDS).to_h.symbolize_keys
  end

  def render_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    attribute = case error.message
    when /description/i then :description
    when /due date/i then :due_on
    when /time zone/i then :time_zone
    when /time/i then :due_at_time
    when /group/i then :inventory_group_id
    else :base
    end
    @deadline.errors.add(attribute, error.message)
    render template, status: :unprocessable_entity
  end
end
