class SupplierReservationRevision < ApplicationRecord
  STATUSES = %w[planned requested superseded abandoned].freeze
  REASON_LIMIT = 500

  belongs_to :agency
  belongs_to :departure
  belongs_to :supplier_arrangement
  belongs_to :supplier_arrangement_version
  belongs_to :supplier_reservation
  belongs_to :actor, class_name: "AgencyUser"

  has_many :scopes, class_name: "SupplierReservationScope", dependent: :restrict_with_exception
  has_many :events, class_name: "SupplierReservationEvent", dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :departure_id, :supplier_arrangement_id,
    :supplier_arrangement_version_id, :supplier_reservation_id, :revision_number

  normalizes :abandoned_reason, with: ->(value) { value.to_s.strip.presence }

  validates :revision_number, numericality: { only_integer: true, greater_than: 0 }
  validates :abandoned_reason, length: { maximum: REASON_LIMIT }, allow_nil: true
  validate :lifecycle_shape

  private

  def lifecycle_shape
    valid = case status
    when "planned"
      requested_at.nil? && abandoned_at.nil? && abandoned_reason.nil?
    when "requested", "superseded"
      requested_at.present? && abandoned_at.nil? && abandoned_reason.nil?
    when "abandoned"
      requested_at.nil? && abandoned_at.present? && abandoned_reason.present?
    end
    errors.add(:base, "Reservation revision lifecycle fields do not match status") unless valid
  end
end
