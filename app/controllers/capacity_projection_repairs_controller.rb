class CapacityProjectionRepairsController < ApplicationController
  include EffectiveCapacityAccess

  before_action :require_departure_management!
  before_action :set_effective_capacity_context

  def create
    RebuildCapacityProjection.new(
      agency: Current.agency,
      pool: @capacity_pool
    ).call
    redirect_to departure_arrangement_capacity_pool_path(
      @departure, @supplier_arrangement, @capacity_pool
    ), notice: "Capacity projection rebuilt from the event ledger."
  rescue AgencyCommand::Error => error
    raise ActiveRecord::RecordNotFound if error.code == :not_found

    redirect_to departure_arrangement_capacity_pool_path(
      @departure, @supplier_arrangement, @capacity_pool
    ), alert: error.message
  end
end
