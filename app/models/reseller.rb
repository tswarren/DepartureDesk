# A reseller relationship (ADR 0017; ACC-13, ACC-16, DOC-08). Schema only in
# step 1: no command creates, pauses or ends one until step 9.
class Reseller < ApplicationRecord
  STATUSES = %w[active booking_paused suspended ended].freeze
  NAME_LIMIT = 160

  belongs_to :agency
  has_many :agency_users, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true, default: "active"

  attr_readonly :agency_id

  normalizes :name, with: ->(value) { value.to_s.strip }

  validates :name, presence: true, length: { maximum: NAME_LIMIT }
end
