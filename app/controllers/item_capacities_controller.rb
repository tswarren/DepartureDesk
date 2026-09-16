class ItemCapacitiesController < ApplicationController
  include ItemCapacityAccess

  before_action :require_departure_view!
  before_action :set_capacity_context
  before_action :require_departure_management!, only: :update

  def show
    load_capacity_graph
  end

  def update
    SetItemCapacityManagement.new(
      agency: Current.agency,
      actor: Current.agency_user,
      definition: @arrangement_item_definition,
      capacity_management: item_capacity_params[:capacity_management],
      lock_version: item_capacity_params[:lock_version]
    ).call
    redirect_to departure_arrangement_item_capacity_path(@departure, @supplier_arrangement, @arrangement_item), notice: "Capacity applicability updated."
  rescue AgencyCommand::Error => error
    add_capacity_applicability_error(error)
    render_capacity_show
  end

  private

  def item_capacity_params
    params.fetch(:arrangement_item_definition, ActionController::Parameters.new).permit(:capacity_management, :lock_version)
  end

  def add_capacity_applicability_error(error)
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    if error.code == :invalid
      @arrangement_item_definition.errors.add(:capacity_management, error.message)
    else
      flash.now[:alert] = error.message
    end
  end
end
