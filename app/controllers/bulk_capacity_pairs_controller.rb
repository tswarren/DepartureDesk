class BulkCapacityPairsController < ApplicationController
  include ItemCapacityAccess

  COMMAND = BulkClassifyCapacityPairs

  before_action :require_departure_view!
  before_action :require_departure_management!
  before_action :set_capacity_context

  def update
    render plain: "Bulk capacity classification is coming in a later M3D.0 phase.",
      status: :not_implemented
  end
end
