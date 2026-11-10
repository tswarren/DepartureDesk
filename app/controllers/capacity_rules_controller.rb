# Who uses capacity on a group (INV-39). A refused change re-renders the
# group with the message above the table (UX consolidation audit C1).
class CapacityRulesController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :require_arrangement_management!
  before_action :set_departure
  before_action :set_arrangement

  def update
    group = @arrangement.inventory_groups.find(params[:group_id])
    SetCapacityRule.new(
      agency: Current.agency, actor: Current.agency_user, departure: @departure, arrangement: @arrangement, group:,
      traveler_type_id: params[:traveler_type_id], uses_capacity: params[:uses_capacity]
    ).call
    redirect_to departure_arrangement_group_path(@departure, @arrangement, group, anchor: "capacity-rules"), notice: "Capacity rule updated."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    @group = @arrangement.inventory_groups.find(params[:group_id])
    @capacity_rule_error = error.message
    render "inventory_groups/show", status: :unprocessable_entity
  end
end
