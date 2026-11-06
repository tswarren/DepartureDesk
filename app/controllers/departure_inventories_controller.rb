# S-17: the Departure's inventory across its live arrangements.
class DepartureInventoriesController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :set_departure

  def show
    @arrangements = @departure.supplier_arrangements.live
      .includes(:supplier, inventory_groups: [ :capacity_projection, { unit_shells: :capacity_events } ])
  end
end
