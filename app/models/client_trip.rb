# A Client Trip: one responsible client, who owes its balance (CLT-02), at
# most one Departure (OVR-02), and a reference issued at creation (REF-04,
# D-94). Its status is derived from its bookings, never stored (BKG-03).
class ClientTrip < ApplicationRecord
  REFERENCE_FORMAT = /\AT-[0-9]{5,}\z/
  STATUS_LABELS = {
    "booked" => "Booked", "travelled" => "Travelled", "quote" => "Quote", "cancelled" => "Cancelled", "not_booked" => "Not booked"
  }.freeze

  belongs_to :agency
  belongs_to :client
  belongs_to :departure, optional: true

  attr_readonly :agency_id, :trip_reference

  validates :trip_reference, presence: true, format: { with: REFERENCE_FORMAT }

  # BKG-03 in D-82's order. Bookings arrive in build step 6b; until then a
  # trip has none and is Not booked.
  def status = "not_booked"

  def status_label = STATUS_LABELS.fetch(status)
end
