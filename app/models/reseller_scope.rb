# Everything a reseller user may read (ACC-14, CLT-25; step 9 plan,
# question 8): the offerings with an open publication to its relationship,
# and the bookings that relationship owns. Clients, travelers and trips are
# reached only through those bookings, or as profiles the relationship's
# users created for them. Built from the user's own agency, so another
# agency's records are never in it; anything outside it is not found.
class ResellerScope
  attr_reader :agency, :reseller

  def initialize(agency_user)
    @agency = agency_user.agency
    @reseller = agency_user.reseller if agency_user.reseller? && agency_user.reseller&.active?
  end

  def active? = @reseller.present?

  def publications
    return OfferingPublication.none unless active?

    OfferingPublication.open.where(agency_id: agency.id, reseller_id: reseller.id)
  end

  def offerings
    Offering.where(agency_id: agency.id, id: publications.select(:offering_id))
  end

  def bookings
    return agency.client_bookings.none unless active?

    agency.client_bookings.where(owner_kind: "reseller", owner_reseller_id: reseller.id)
  end

  def trips
    agency.client_trips.where(id: bookings.select(:client_trip_id))
  end

  # Travelers on its bookings, and those its users created (CLT-25).
  def travelers
    return agency.travelers.none unless active?

    on_bookings = BookingTraveler.where(client_booking_id: bookings.select(:id)).where.not(traveler_id: nil).select(:traveler_id)
    agency.travelers.where(id: on_bookings).or(agency.travelers.where(created_by_id: user_ids))
  end

  def clients
    return agency.clients.none unless active?

    agency.clients.where(id: trips.select(:client_id)).or(agency.clients.where(created_by_id: user_ids))
  end

  def published?(offering) = publications.exists?(offering_id: offering.id)

  private

  def user_ids = agency.agency_users.where(reseller_id: reseller.id).select(:id)
end
