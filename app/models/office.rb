class Office < ApplicationRecord
  CODE_FORMAT = /\A[A-Z][A-Z0-9]{1,9}\z/

  STATUSES = %w[
    active
    inactive
  ].freeze

  belongs_to :agency
  has_many :office_assignments, dependent: :restrict_with_exception
  has_many :client_profiles,
    foreign_key: :responsible_office_id,
    inverse_of: :responsible_office,
    dependent: :restrict_with_exception
  has_many :supplier_profiles,
    foreign_key: :responsible_office_id,
    inverse_of: :responsible_office,
    dependent: :restrict_with_exception
  has_many :sessions, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  normalizes :name, with: ->(value) { value&.strip }
  normalizes :code, with: ->(value) { value&.strip&.upcase }
  normalizes :default_timezone, with: ->(value) { value&.strip }

  validates :name, presence: true
  validates :code,
    presence: true,
    format: { with: CODE_FORMAT, message: "must be 2–10 uppercase letters or digits and start with a letter" },
    uniqueness: { scope: :agency_id }
  validates :default_timezone, presence: true
  validate :default_timezone_must_be_valid
  validate :code_is_immutable, on: :update

  def self.next_main_code(agency)
    existing = agency.offices.where("code LIKE 'MAIN%'").pluck(:code).to_set
    candidate = "MAIN"
    suffix = 1

    while existing.include?(candidate)
      suffix += 1
      candidate = "MAIN#{suffix}"
      if candidate.length > 10
        raise ArgumentError, "No remaining MAIN office code is available."
      end
    end

    candidate
  end

  def assigned_staff_count
    assignments = office_assignments
    if assignments.loaded?
      assignments.count { |assignment| assignment.active? && assignment.agency_membership&.staff? }
    else
      assignments.active.joins(:agency_membership).where(agency_memberships: { role: "staff" }).count
    end
  end

  private

  def default_timezone_must_be_valid
    TZInfo::Timezone.get(default_timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:default_timezone, "is not a recognized IANA timezone")
  end

  def code_is_immutable
    return unless code_changed? && persisted?

    errors.add(:code, "cannot be changed")
  end
end
