class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    [ password_salt, password_reset_version ]
  end
  has_many :sessions, dependent: :destroy
  has_many :agency_memberships, dependent: :restrict_with_exception
  has_many :agencies, through: :agency_memberships
  has_many :active_agency_memberships,
    -> { active },
    class_name: "AgencyMembership"

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :first_name, :last_name, with: ->(value) { value&.strip }
  normalizes :preferred_name, with: ->(value) { value&.strip.presence }

  validates :first_name, :last_name, presence: true

  def display_name
    preferred_name.presence || "#{first_name} #{last_name}".squish
  end

  def usable_agency_membership
    memberships = active_agency_memberships
      .includes(:agency)
      .limit(2)
      .to_a

    return unless memberships.one?

    membership = memberships.first
    membership if membership.agency.active?
  end

  def agency
    usable_agency_membership&.agency
  end
end
