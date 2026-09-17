class SupplierConfirmationReservationResponseLink < ApplicationRecord
  include AppendOnlyRecord

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_confirmation
  belongs_to :supplier_reservation
  belongs_to :supplier_reservation_revision
  belongs_to :supplier_reservation_event

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id
end
