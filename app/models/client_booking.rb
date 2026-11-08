# One purchase of one offering for a set of travelers on one Client Trip
# (BKG-05), referenced from its trip (REF-04). Its status (BKG-06) is
# independent of its allocations' states (INV-18): no status implies another.
class ClientBooking < ApplicationRecord
  STATUSES = %w[draft confirmed discarded cancelled].freeze
  STATUS_LABELS = { "draft" => "Draft", "confirmed" => "Confirmed", "discarded" => "Discarded", "cancelled" => "Cancelled" }.freeze

  belongs_to :agency
  belongs_to :client_trip
  belongs_to :offering
  belongs_to :created_by, class_name: "AgencyUser"
  belongs_to :client_terms_version, optional: true
  has_many :booking_travelers, -> { order(:position, :created_at) }, inverse_of: :client_booking, dependent: :restrict_with_exception
  has_many :choice_selections, -> { where(removed_at: nil).order(:unit_number, :created_at) }, inverse_of: :client_booking, dependent: :restrict_with_exception
  has_many :inventory_allocations, inverse_of: :client_booking, dependent: :restrict_with_exception
  has_many :price_lines, class_name: "BookingPriceLine", inverse_of: :client_booking, dependent: :restrict_with_exception
  has_many :acceptances, -> { order(:recorded_at) }, class_name: "BookingAcceptance", dependent: :restrict_with_exception
  has_one :client_charge, dependent: :restrict_with_exception
  has_many :cost_lines, dependent: :restrict_with_exception
  has_many :expected_commissions, dependent: :restrict_with_exception
  has_many :supplier_reservations, -> { order(:requested_at) }, inverse_of: :client_booking, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "draft", prefix: :status

  attr_readonly :agency_id, :client_trip_id, :offering_id, :sequence, :booking_reference

  delegate :departure, to: :client_trip

  def status_label = STATUS_LABELS.fetch(status)

  # Allocations that consume capacity at the instant: Reserved, or Held
  # with an expiry still ahead (D-88). A lapsed hold stops counting at read
  # time, with no job.
  def consuming_allocations(at: Clock.current.now)
    inventory_allocations.select { |allocation| allocation.consuming?(at:) }
  end

  # :held, :expired or :none, with the hold's expiry for the first two.
  def hold_state(at: Clock.current.now)
    held = inventory_allocations.select(&:state_held?)
    return [ :none, nil ] if held.empty?

    active = held.select { |allocation| allocation.consuming?(at:) }
    active.any? ? [ :held, active.map(&:hold_expires_at).min ] : [ :expired, held.map(&:hold_expires_at).max ]
  end

  def hold_extended? = consuming_allocations.any? { |allocation| allocation.hold_extended_at.present? }

  def total_minor_units = price_lines.sum(&:amount_minor_units)

  def currency = offering.currency

  def latest_acceptance = acceptances.max_by(&:recorded_at)

  # BKG-39: the latest acceptance, if it still covers the current price and terms.
  def current_acceptance
    acceptance = latest_acceptance
    acceptance if acceptance&.covers?(self)
  end
end
