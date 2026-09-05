class AgencyMembership < ApplicationRecord
  INVITATION_PURPOSE = "invitation"
  INVITATION_TTL = 7.days
  INVITATION_STATUSES = %w[invited].freeze

  ROLES = %w[
    staff
    administrator
  ].freeze

  STATUSES = %w[
    invited
    active
    suspended
    revoked
  ].freeze

  belongs_to :user
  belongs_to :agency

  enum :role, ROLES.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  generates_token_for :invitation, expires_in: INVITATION_TTL do
    [ id, invitation_version, status, INVITATION_PURPOSE ]
  end

  validates :user_id, uniqueness: { scope: :agency_id }
  validates :user_id,
    uniqueness: {
      conditions: -> { where(status: "active") },
      message: "already has an active agency membership"
    },
    if: :active?

  def invitation_token
    generate_token_for(:invitation)
  end

  def invitation_open?
    invited?
  end
end
