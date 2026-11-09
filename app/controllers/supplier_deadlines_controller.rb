# S-15: record and change an arrangement's supplier deadlines.
class SupplierDeadlinesController < ApplicationController
  include ArrangementAccess

  ERROR_FIELDS = [ [ :description, /description/i ], [ :due_on, /due date/i ], [ :time_zone, /time zone/i ], [ :due_at_time, /time/i ], [ :inventory_group_id, /group/i ] ].freeze

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
    render_form_error(error, @deadline, :new, ERROR_FIELDS)
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
    render_form_error(error, @deadline, :edit, ERROR_FIELDS)
  end

  private

  def set_deadline
    @deadline = @arrangement.deadlines.find(params[:id])
  end

  # A blank name takes what is due, such as "Final count or manifest".
  def deadline_params
    values = params.require(:supplier_deadline).permit(*FIELDS).to_h.symbolize_keys
    values[:description] = helpers.deadline_type_label(values[:deadline_type]) if values[:description].blank? && values[:deadline_type].in?(SupplierDeadline::TYPES)
    values
  end
end
