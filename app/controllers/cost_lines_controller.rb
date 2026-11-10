class CostLinesController < ApplicationController
  include SupplierMoneyAccess

  FIELDS = %i[scope inventory_group_id unit_shell_ids description basis rate quantity percentage base_cost_line_id stage].freeze
  # Field and message prefix, checked in order.
  LABELS = [ [ :description, "Description" ], [ :rate, "Amount" ], [ :rate, "Rate" ], [ :quantity, "Quantity" ], [ :percentage, "Percentage" ] ].freeze

  before_action :require_arrangement_view!
  before_action :require_supplier_cost_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_cost_line, only: %i[edit update destroy]

  def new
    @cost_line = @arrangement.cost_lines.new(scope: params[:scope].presence_in(CostLine::SCOPES) || "arrangement", basis: "fixed", stage: "committed")
    @values = {}
  end

  def create
    SaveCostLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, attributes: cost_params).call
    redirect_to_money "Cost line added."
  rescue AgencyCommand::Error => error
    @cost_line = @arrangement.cost_lines.new(cost_params.slice("scope", "basis", "stage", "description").select { |_k, v| v.present? })
    @values = cost_params
    render_form_error(error, @cost_line, :new, LABELS)
  end

  def edit
    @values = {
      "rate" => MoneyInput.display(@cost_line.rate_minor_units, @arrangement.currency), "quantity" => @cost_line.quantity,
      "percentage" => @cost_line.percentage&.to_s("F"), "base_cost_line_id" => @cost_line.base_cost_line_id,
      "inventory_group_id" => @cost_line.inventory_group_id, "unit_shell_ids" => @cost_line.unit_shell_ids
    }
  end

  def update
    SaveCostLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, cost_line: @cost_line,
      attributes: cost_params, lock_version: params.dig(:cost_line, :lock_version)).call
    redirect_to_money "Cost line updated."
  rescue AgencyCommand::Error => error
    @values = cost_params
    render_form_error(error, @cost_line, :edit, LABELS)
  end

  def destroy
    RemoveCostLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, cost_line: @cost_line).call
    redirect_to_money "Cost line removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_costs_path(@departure, @arrangement, anchor: "supplier-cost"), alert: error.message
  end

  private

  def set_cost_line
    @cost_line = @arrangement.cost_lines.find(params[:id])
  end

  def cost_params = money_params(:cost_line, FIELDS)
end
