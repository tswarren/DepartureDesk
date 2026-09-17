class ItemCostsController < ApplicationController
  include SupplierCostAccess

  before_action :require_departure_view!
  skip_before_action :require_departure_management!
  before_action :require_item!

  def show
    @item_cost_sources = cost_sources
      .includes(:charging_supplier, supplier_cost_definitions: [ :supplier_cost_components ])
      .order(:position, :id)
      .to_a
    @categories = @supplier_arrangement_version.supplier_cost_participant_categories
      .where(arrangement_item_id: @arrangement_item.id)
      .order(:position, :id)
      .to_a
    @assumptions = @supplier_arrangement_version.supplier_cost_usage_assumptions
      .includes(supplier_cost_occupancy_profiles: :supplier_cost_occupancy_profile_positions)
      .where(arrangement_item_id: @arrangement_item.id)
      .order(:id)
      .to_a
    @occurrence_definitions_by_item_id = {
      @arrangement_item.id => @supplier_arrangement_version.service_occurrence_definitions
        .where(arrangement_item_id: @arrangement_item.id)
        .order(:starts_on, :id).to_a
    }
    @resource_definitions_by_item_id = {
      @arrangement_item.id => @supplier_arrangement_version.supplier_resource_definitions
        .where(arrangement_item_id: @arrangement_item.id)
        .order(:position, :id).to_a
    }
    @editable = cost_ordinary_editable?
  end

  private

  def require_item!
    raise ActiveRecord::RecordNotFound unless @arrangement_item
  end
end
