# The supplier rate table editor (S-14, SUP-35). Viewing needs the ACC-31
# permissions; editing needs Supplier arrangements.
class SupplierRateLinesController < ApplicationController
  include ArrangementAccess

  FORM_FIELDS = SaveSupplierRateLine::FIELDS

  before_action :require_arrangement_view!
  before_action :require_supplier_cost_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement
  before_action :set_rate_line, only: %i[edit update destroy]

  def new
    @rate_line = @arrangement.rate_lines.new(inventory_group_id: params[:group_id], occupancy_position: "guest_1")
    @values = { "inventory_group_id" => params[:group_id], "occupancy_position" => "guest_1" }
  end

  def create
    result = SaveSupplierRateLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, attributes: rate_line_params).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "rate-table"), notice: "Rate added for #{result.record.inventory_group.label}."
  rescue AgencyCommand::Error => error
    @rate_line = @arrangement.rate_lines.new
    render_error(error, :new)
  end

  def edit
    @values = form_values(@rate_line)
  end

  def update
    SaveSupplierRateLine.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, rate_line: @rate_line,
      attributes: rate_line_params, lock_version: params.dig(:supplier_rate_line, :lock_version)
    ).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "rate-table"), notice: "Rate updated."
  rescue AgencyCommand::Error => error
    render_error(error, :edit)
  end

  def destroy
    RemoveSupplierRateLine.new(agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, rate_line: @rate_line).call
    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "rate-table"), notice: "Rate removed."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_path(@departure, @arrangement, anchor: "rate-table"), alert: error.message
  end

  private

  def require_supplier_cost_view!
    require_permission!(:view_supplier_costs)
  end

  def set_rate_line
    @rate_line = @arrangement.rate_lines.find(params[:id])
  end

  def rate_line_params
    params.require(:supplier_rate_line).permit(*FORM_FIELDS).to_h
  end

  def form_values(line)
    currency = @arrangement.currency
    {
      "inventory_group_id" => line.inventory_group_id, "occupancy_position" => line.occupancy_position, "traveler_type_id" => line.traveler_type_id,
      "base_fare" => MoneyInput.display(line.base_fare_minor_units, currency),
      "non_commissionable_fees" => MoneyInput.display(line.non_commissionable_fees_minor_units, currency),
      "taxes" => MoneyInput.display(line.taxes_minor_units, currency),
      "discount" => MoneyInput.display(line.discount_minor_units, currency),
      "commission_rate" => line.commission_rate&.to_s("F"),
      "commission_amount" => MoneyInput.display(line.commission_minor_units, currency)
    }
  end

  # A message that starts with a field's name is shown on that field.
  def render_error(error, template)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @values = rate_line_params
    attribute = FORM_FIELDS.find { |field| error.message.start_with?(SupplierRateLine.human_attribute_name(field)) }
    if attribute
      @rate_line.errors.add(attribute, error.message.delete_prefix(SupplierRateLine.human_attribute_name(attribute)).strip)
    else
      @rate_line.errors.add(:base, error.message)
    end
    render template, status: :unprocessable_entity
  end
end
