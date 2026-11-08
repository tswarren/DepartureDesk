# A supplier reservation (INV-33 to INV-37): a request to the supplier for
# a booking's units from one arrangement, at the scope the arrangement
# defines (SUP-10), with its own status. It is never created by an
# allocation, and its status is never derived from the allocation or the
# client booking, nor theirs from it. Starting one is local tracking.
class SupplierReservation < ApplicationRecord
  STATUSES = %w[requested confirmed declined cancelled].freeze
  STATUS_LABELS = { "requested" => "Requested", "confirmed" => "Confirmed", "declined" => "Declined", "cancelled" => "Cancelled" }.freeze
  REFERENCE_LIMIT = 120
  NOTE_LIMIT = 2000

  belongs_to :agency
  belongs_to :supplier_arrangement
  belongs_to :client_booking
  belongs_to :requested_by, class_name: "AgencyUser"
  belongs_to :responded_by, class_name: "AgencyUser", optional: true
  has_many :units, class_name: "SupplierReservationUnit", inverse_of: :supplier_reservation, dependent: :restrict_with_exception
  has_many :choice_selections, through: :units
  has_many :events, -> { order(:recorded_at) }, class_name: "SupplierReservationEvent", inverse_of: :supplier_reservation, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "requested", prefix: true

  attr_readonly :agency_id, :supplier_arrangement_id, :client_booking_id

  normalizes :supplier_reference, with: ->(value) { value.to_s.squish.presence }
  normalizes :response_note, with: ->(value) { value.to_s.strip.presence }

  validates :supplier_reference, length: { maximum: REFERENCE_LIMIT }
  validates :response_note, length: { maximum: NOTE_LIMIT }

  scope :open, -> { where(status: %w[requested confirmed]) }

  def status_label = STATUS_LABELS.fetch(status)
end
