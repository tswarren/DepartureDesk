# A dated supplier reservation event: the request, or the supplier's answer
# (INV-26). Append-only, in the application and in PostgreSQL.
class SupplierReservationEvent < ApplicationRecord
  belongs_to :agency
  belongs_to :supplier_reservation, inverse_of: :events
  belongs_to :recorded_by, class_name: "AgencyUser"

  validates :event_type, inclusion: { in: SupplierReservation::STATUSES }

  before_update { raise ActiveRecord::ReadOnlyRecord, "Supplier reservation events are append-only." }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "Supplier reservation events are append-only." }
end
