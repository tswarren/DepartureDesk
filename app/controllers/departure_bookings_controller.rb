# S-25: every booking on the Departure, with its owner, status, cabin,
# travelers, subtotal and hold (BKG-06, D-80).
class DepartureBookingsController < ApplicationController
  include DepartureAccess

  before_action :require_departure_view!
  before_action -> { require_permission!(:view_bookings) }
  before_action :set_departure

  def index
    @bookings = Current.agency.client_bookings.joins(:client_trip).where(client_trips: { departure_id: @departure.id })
      .includes(:price_lines, :inventory_allocations, { offering: :choices }, booking_travelers: :traveler,
        choice_selections: { option: :choice }, client_trip: { client: %i[client_person client_organization] })
      .order("client_trips.trip_reference", :sequence)
  end
end
