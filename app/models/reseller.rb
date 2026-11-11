# A reseller relationship (ADR 0017; ACC-13, ACC-16, DOC-08), which is also
# its one channel (DEP-07, D-68). Staff authorize one and set its name and
# direct-contact setting (step 9). Pause, suspension and ending are not built,
# so every relationship is Active in Slice 1.
class Reseller < ApplicationRecord
  STATUSES = %w[active booking_paused suspended ended].freeze
  NAME_LIMIT = 160

  belongs_to :agency
  has_many :agency_users, dependent: :restrict_with_exception
  has_many :offering_publications, dependent: :restrict_with_exception
  has_many :owned_bookings, class_name: "ClientBooking", foreign_key: :owner_reseller_id, inverse_of: :owner_reseller, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }

  def status_label = status.humanize
end
