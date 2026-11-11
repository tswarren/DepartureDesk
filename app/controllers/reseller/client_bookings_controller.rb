# R-03: the booking workspace for a booking the reseller's relationship
# owns (ACC-15, CMN-52). It never searches the agency's directory, and
# offers only the client's travelers the reseller can see (CLT-25).
class Reseller::ClientBookingsController < ::ClientBookingsController
  include ResellerBookingAccess

  private

  def linkable_travelers = @trip.client.traveler_links.where(traveler_id: reseller_scope.travelers.select(:id))

  def directory_search? = false
end
