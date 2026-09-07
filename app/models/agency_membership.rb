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
  belongs_to :person_party,
    class_name: "Person",
    foreign_key: :person_party_id,
    inverse_of: :agency_membership
  has_many :office_assignments, dependent: :restrict_with_exception
  has_many :advised_client_profiles,
    class_name: "ClientProfile",
    foreign_key: :primary_advisor_membership_id,
    inverse_of: false,
    dependent: :restrict_with_exception

  enum :role, ROLES.index_by(&:itself), validate: true
  enum :status, STATUSES.index_by(&:itself), validate: true

  generates_token_for :invitation, expires_in: INVITATION_TTL do
    [ id, invitation_version, status, INVITATION_PURPOSE ]
  end

  validates :person_party_id, uniqueness: { scope: :agency_id }

  def agency_display_name
    person_party&.party&.display_name.presence || user.display_name
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

  def assigned_offices
    agency.offices.where(id: office_assignments.active.select(:office_id))
  end

  def accessible_offices
    return Office.none unless active? && agency.active?

    if administrator?
      agency.offices.active
    else
      agency.offices.active.where(id: office_assignments.active.select(:office_id))
    end
  end

  def can_access_office?(office)
    return false unless office

    accessible_offices.where(id: office.id).exists?
  end

  def default_office
    office_assignments.active.find_by(is_default: true)&.office
  end

  def has_active_office_assignment?
    office_assignments.active.joins(:office).where(offices: { status: "active", agency_id: agency_id }).exists?
  end

  def has_active_default_office?
    default = default_office
    default&.active? && default.agency_id == agency_id
  end

  def activation_office_ready?
    if staff?
      has_active_office_assignment?
    elsif administrator?
      return true unless agency.offices.active.exists?

      has_active_default_office?
    else
      false
    end
  end
end
