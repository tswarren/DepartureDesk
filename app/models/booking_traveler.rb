# A traveler placed on a booking (CLT-13): a traveler profile or, on a
# hold, a placeholder such as "Guest 2" (CLT-15), with the traveler type
# staff choose (BKG-21, INV-39). The name as booked is snapshotted at
# confirmation in build step 6c.
class BookingTraveler < ApplicationRecord
  PLACEHOLDER_LIMIT = 40

  belongs_to :agency
  belongs_to :client_booking, inverse_of: :booking_travelers
  belongs_to :traveler, optional: true
  belongs_to :traveler_type, optional: true
  has_many :selection_occupants, dependent: :restrict_with_exception

  attr_readonly :agency_id, :client_booking_id

  normalizes :placeholder_label, with: ->(value) { value.to_s.squish.presence }

  validates :placeholder_label, length: { maximum: PLACEHOLDER_LIMIT }
  validates :traveler_id, uniqueness: { scope: :client_booking_id, message: "is already on this booking" }, allow_nil: true
  validate :traveler_or_placeholder

  def placeholder? = traveler_id.nil?

  def display_name = traveler ? traveler.display_name : placeholder_label

  # CLT-15: what confirmation needs from each traveler.
  def named_for_confirmation? = traveler.present? && traveler.legal_name_complete? && traveler.date_of_birth.present?

  def counts_as_adult? = traveler_type&.counts_as_adult? || false

  private

  def traveler_or_placeholder
    return if traveler_id.present? ^ placeholder_label.present?

    errors.add(:base, "Choose a traveler or enter a placeholder such as Guest 2, not both")
  end
end
