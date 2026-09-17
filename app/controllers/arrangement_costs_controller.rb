class ArrangementCostsController < ApplicationController
  include SupplierCostAccess

  before_action :require_departure_view!
  skip_before_action :require_departure_management!

  def show
    @arrangement_cost_sources = cost_sources
      .includes(:charging_supplier, supplier_cost_definitions: [ :supplier_cost_components ])
      .order(:position, :id)
      .to_a
    @occurrence_definitions_by_item_id = {}
    @resource_definitions_by_item_id = {}
    @editable = cost_ordinary_editable?
    @cost_forecast = EvaluateSupplierCostForecast.new(
      agency: Current.agency, departure: @departure, arrangement: @supplier_arrangement
    ).call.arrangements.first
  end
end
