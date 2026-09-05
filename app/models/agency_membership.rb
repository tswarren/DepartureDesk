class AgencyMembership < ApplicationRecord
  ROLES = %w[
    staff
    administrator
  ].freeze

  STATUSES = %w[
    active
    suspended
  ].freeze

  belongs_to :user
  belongs_to :agency

  enum :role, ROLES.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  validates :user_id, uniqueness: { scope: :agency_id }
  validates :user_id,
    uniqueness: {
      conditions: -> { where(status: "active") },
      message: "already has an active agency membership"
    },
    if: :active?
end
