# S-17: the Departure's inventory across its live arrangements.
class DepartureInventoriesController < ApplicationController
  include ArrangementAccess

  before_action :require_arrangement_view!
  before_action :set_departure

  def show
    @arrangements = @departure.supplier_arrangements.live
      .includes(:supplier, inventory_groups: [ :capacity_projection, :capacity_rules, :capacity_events, { inventory_allocations: { choice_selection: [ { option: :choice }, { occupants: { booking_traveler: :traveler } } ] } },
        { unit_shells: %i[capacity_events inventory_allocations] } ])
  end
end
