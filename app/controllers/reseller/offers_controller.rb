# R-02: one offer published to the reseller: the package, its choices and
# client prices, and the places left on each option. Supplier cost, the
# rate table and inventory detail are never loaded (ACC-14, ACC-31).
class Reseller::OffersController < ApplicationController
  include ResellerArea

  before_action -> { require_permission!(:reseller_view_offers) }

  def show
    @offering = reseller_scope.offerings.includes(:departure).find(params[:id])
    @choices = @offering.choices.includes(options: [ { prices: :traveler_type }, { inventory_group: %i[capacity_events inventory_allocations unit_shells] } ]).to_a
  end
end
