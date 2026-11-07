# A numbered version of a Departure's client terms (BKG-28, D-76): the
# agency's reusable wording as copied when it was made, the Departure's own
# wording, the cancellation tiers (the agency's unless it overrides them,
# BKG-31) and the payment schedule template (CMN-09). A booking that
# accepts it locks it (step 6); a locked version never changes.
class ClientTermsVersion < ApplicationRecord
  WORDING_LIMIT = 20_000

  belongs_to :agency
  belongs_to :departure
  belongs_to :copied_from_departure, class_name: "Departure", optional: true
  has_many :own_cancellation_tiers, -> { ordered }, class_name: "ClientCancellationTier", inverse_of: :client_terms_version, dependent: :restrict_with_exception
  has_many :schedule_lines, -> { ordered }, class_name: "ClientPaymentScheduleLine", inverse_of: :client_terms_version, dependent: :restrict_with_exception

  attr_readonly :agency_id, :departure_id, :version_number

  normalizes :agency_wording, :departure_wording, with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }

  validates :version_number, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :agency_wording, :departure_wording, length: { maximum: WORDING_LIMIT }, allow_nil: true

  def locked? = locked_at.present?

  # BKG-31: the override when there is one, else the agency's defaults.
  def cancellation_tiers
    overrides_cancellation_tiers? ? own_cancellation_tiers : agency.agency_cancellation_tiers.ordered
  end

  # What the terms still need before step 6 will present them.
  def booking_blockers
    schedule_lines.any?(&:basis_balance?) ? [] : [ "Add a balance line to the payment schedule." ]
  end
end
