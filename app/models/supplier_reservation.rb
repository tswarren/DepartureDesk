class SupplierReservation < ApplicationRecord
  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :booking_supplier, class_name: "Supplier"

  has_many :revisions, class_name: "SupplierReservationRevision", dependent: :restrict_with_exception
  has_many :scopes, class_name: "SupplierReservationScope", dependent: :restrict_with_exception
  has_many :events, class_name: "SupplierReservationEvent", dependent: :restrict_with_exception
  has_one :projection, class_name: "SupplierReservationProjection", dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id, :booking_supplier_id
end
