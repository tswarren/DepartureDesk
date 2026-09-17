class CapacityPairPoolSetupsController < ApplicationController
  include ItemCapacityAccess

  COMMAND = ConfigureCapacityPairWithPool

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_capacity_context

  def create
    render plain: "Capacity pair pool setup is coming in a later M3D.0 phase.",
      status: :not_implemented
  end
end
