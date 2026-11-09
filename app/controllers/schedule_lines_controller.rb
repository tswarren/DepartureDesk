class ScheduleLinesController < ApplicationController
  include SupplierMoneyAccess

  FIELDS = %i[
    description cost_line_id supplier_deadline_id inventory_group_id amount_kind amount rate percentage
    when due_on trigger_type days_after
  ].freeze
  # Field and message prefix, checked in order: "Amount per unit" before "Amount".
  LABELS = [
    [ :description, "Description" ], [ :rate, "Amount per unit" ], [ :amount, "Amount" ], [ :percentage, "Percentage" ],
    [ :days_after, "Days after the event" ], [ :due_on, "Due date" ], [ :trigger_type, "Choose the event" ]
  ].freeze

  before_action :require_arrangement_view!
  before_action :require_supplier_cost_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_schedule_line, only: %i[edit update]

  def new
    @schedule_line = @arrangement.schedule_lines.new(amount_kind: "fixed", due_rule: "fixed_date", cost_line_id: params[:cost_line_id])
    @values = {}
  end

  def create
    SaveScheduleLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, attributes: line_params).call
    redirect_to_money "Payment added.", anchor: "supplier-payments"
  rescue AgencyCommand::Error => error
    @schedule_line = @arrangement.schedule_lines.new(line_params.slice("description", "amount_kind", "due_rule", "due_on", "trigger_type").select { |_k, v| v.present? })
    @values = line_params.merge("when" => params.dig(:schedule_line, :when))
    render_form_error(error, @schedule_line, :new, LABELS)
  end

  def edit
    currency = @arrangement.currency
    @values = {
      "amount" => MoneyInput.display(@schedule_line.amount_minor_units, currency), "rate" => MoneyInput.display(@schedule_line.rate_minor_units, currency),
      "percentage" => @schedule_line.percentage&.to_s("F"), "days_after" => @schedule_line.days_after,
      "cost_line_id" => @schedule_line.cost_line_id, "supplier_deadline_id" => @schedule_line.supplier_deadline_id,
      "inventory_group_id" => @schedule_line.inventory_group_id
    }
  end

  def update
    SaveScheduleLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, schedule_line: @schedule_line,
      attributes: line_params, lock_version: params.dig(:schedule_line, :lock_version)).call
    redirect_to_money "Payment updated.", anchor: "supplier-payments"
  rescue AgencyCommand::Error => error
    @values = line_params.merge("when" => params.dig(:schedule_line, :when))
    render_form_error(error, @schedule_line, :edit, LABELS)
  end

  private

  def set_schedule_line
    @schedule_line = @arrangement.schedule_lines.find(params[:id])
  end

  # The form's "when" choice becomes a due rule and, for booking, its event (SMN-04).
  def line_params
    @line_params ||= begin
      values = money_params(:schedule_line, FIELDS)
      choice = values.delete("when")
      values.merge(due_rule_for(choice, values))
    end
  end

  def due_rule_for(choice, values)
    case choice
    when "date" then { "due_rule" => "fixed_date", "trigger_type" => nil, "days_after" => nil }
    when "booked" then { "due_rule" => "event", "trigger_type" => "client_booking_confirmed", "due_on" => nil, "days_after" => nil }
    when "booked_or_date" then { "due_rule" => "earlier_of", "trigger_type" => "client_booking_confirmed", "days_after" => nil }
    when "after_event"
      days = values["days_after"].to_i
      { "due_rule" => days.positive? ? "event_plus_days" : "event", "due_on" => nil, "days_after" => (days if days.positive?) }
    else {}
    end
  end
end
