class SupplierReservationResource < ApplicationRecord
  belongs_to :agency
  belongs_to :office
  belongs_to :departure
  belongs_to :arrangement, class_name: "SupplierArrangement"
  belongs_to :reservation, class_name: "SupplierReservation", inverse_of: :supplier_reservation_resources
  belongs_to :resource, class_name: "SupplierResource", inverse_of: :supplier_reservation_resources
  belongs_to :created_by_membership, class_name: "AgencyMembership", inverse_of: false

  validates :reservation_id, uniqueness: { scope: :resource_id }
  validate :same_scope

  private

  def same_scope
    expected = [ agency_id, office_id, departure_id, arrangement_id ]
    errors.add(:reservation, "must belong to the same arrangement") if reservation && [ reservation.agency_id, reservation.office_id, reservation.departure_id, reservation.arrangement_id ] != expected
    errors.add(:resource, "must belong to the same arrangement") if resource && [ resource.agency_id, resource.office_id, resource.departure_id, resource.arrangement_id ] != expected
  end
end
