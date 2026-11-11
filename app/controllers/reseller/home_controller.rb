# R-01: the reseller's home (S-01 for a reseller user): the offers
# published to its relationship and the bookings it owns, with each
# booking's status, hold and balance (ACC-14, CMN-52).
class Reseller::HomeController < ApplicationController
  include ResellerArea

  before_action -> { require_permission!(:reseller_view_offers) }

  def show
    @offerings = reseller_scope.offerings.includes(:departure).order(:name).to_a
    @bookings = reseller_scope.bookings.where.not(status: "discarded")
      .includes(:offering, :price_lines, :inventory_allocations, { client_charge: [ :lines, { installments: :applications } ] }, client_trip: [ :departure, { client: %i[client_person client_organization] } ])
      .order(:booking_reference).to_a
  end
end
