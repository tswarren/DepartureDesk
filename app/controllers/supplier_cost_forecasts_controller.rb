class SupplierCostForecastsController < ApplicationController
  include SupplierCostAccess

  def show
    @forecast = EvaluateSupplierCostForecast.new(
      agency: Current.agency, departure: @departure, arrangement: @supplier_arrangement
    ).call.arrangements.first
    @items_by_id = @supplier_arrangement_version.arrangement_item_definitions
      .includes(:arrangement_item).index_by(&:arrangement_item_id)
    @sources_by_id = @supplier_arrangement_version.supplier_cost_sources
      .includes(:charging_supplier).index_by(&:id)
  end
end
