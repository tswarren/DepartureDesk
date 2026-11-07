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
  has_many :client_bookings, -> { order(:sequence) }, inverse_of: :client_trip, dependent: :restrict_with_exception

  attr_readonly :agency_id, :trip_reference

  validates :trip_reference, presence: true, format: { with: REFERENCE_FORMAT }

  # BKG-03 in D-82's order. Booked and Travelled need confirmed bookings,
  # which build step 6c adds; service end dates decide between them.
  def status
    bookings = client_bookings.to_a
    confirmed = bookings.select(&:status_confirmed?)
    return travelled?(confirmed) ? "travelled" : "booked" if confirmed.any?
    return "quote" if bookings.any?(&:status_draft?)
    return "cancelled" if bookings.any?(&:status_cancelled?)

    "not_booked"
  end

  def status_label = STATUS_LABELS.fetch(status)

  private

  # Every service on every confirmed booking has ended; an unknown end counts as not ended.
  def travelled?(confirmed)
    ends = confirmed.flat_map { |booking| booking.choice_selections.map { |selection| selection.inventory_group.ends_on } }
    ends.any? && ends.all? { |ends_on| ends_on && ends_on < Clock.current.today_in(agency.default_timezone) }
  end
end
