module SupplierCostAccess
  extend ActiveSupport::Concern

  include SupplierArrangementAccess

  included do
    before_action :require_departure_view!
    before_action :require_departure_management!, unless: -> { action_name == "show" }
    before_action :set_departure
    before_action :set_supplier_arrangement
    before_action :set_initial_version
    before_action :set_cost_item
    helper_method :cost_ordinary_editable?, :cost_source_ordinary_editable?, :cost_source_cleanup_editable?
  end

  private

  def set_cost_item
    return unless params[:item_id]

    @arrangement_item = @supplier_arrangement.arrangement_items.find(params[:item_id])
    @arrangement_item_definition = @supplier_arrangement_version.arrangement_item_definitions.find_by!(
      arrangement_item_id: @arrangement_item.id
    )
  end

  def cost_sources
    scope = @supplier_arrangement_version.supplier_cost_sources
    scope.where(arrangement_item_id: @arrangement_item&.id)
  end

  def set_cost_source
    @supplier_cost_source = cost_sources.find(params[:cost_source_id] || params[:cost_id] || params[:id])
  end

  def set_cost_definition
    set_cost_source unless @supplier_cost_source
    @supplier_cost_definition = @supplier_cost_source.supplier_cost_definitions.find(
      params[:definition_id] || params[:id]
    )
  end

  def costs_workspace_path_for(anchor: nil)
    if @arrangement_item
      departure_arrangement_item_costs_workspace_path(
        @departure, @supplier_arrangement, @arrangement_item, anchor:
      )
    else
      departure_arrangement_costs_workspace_path(@departure, @supplier_arrangement, anchor:)
    end
  end

  def arrangement_location(anchor = nil)
    costs_workspace_path_for(anchor:)
  end

  def handle_cost_error(error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to costs_workspace_path_for, alert: error.message
  end

  def cost_ordinary_editable?
    manage = Current.agency_user.permitted?(:manage_departures)
    draft_graph = @supplier_arrangement.draft? && @supplier_arrangement_version.draft?
    contractor_active = @supplier_arrangement.contracting_supplier.active?
    manage && draft_graph && (@departure.draft? || @departure.active?) && contractor_active
  end

  def cost_source_ordinary_editable?(source)
    cost_ordinary_editable? && source.charging_supplier.active?
  end

  def cost_source_cleanup_editable?(source)
    manage = Current.agency_user.permitted?(:manage_departures)
    draft_graph = @supplier_arrangement.draft? && @supplier_arrangement_version.draft?
    departure_ok = @departure.draft? || @departure.active? || @departure.departed?
    manage && draft_graph && departure_ok && !source.charging_supplier.active?
  end
end
