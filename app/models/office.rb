class Office < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  CODE_FORMAT = /\A[A-Z][A-Z0-9]{1,9}\z/

  belongs_to :agency
  has_many :default_agency_users, class_name: "AgencyUser", foreign_key: :default_office_id, inverse_of: :default_office, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :code

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :code, with: ->(value) { normalize_code(value) }
  normalizes :default_timezone, with: ->(value) { value.to_s.strip }

  validates :name, :code, :default_timezone, presence: true
  validates :code, uniqueness: { scope: :agency_id }, format: { with: CODE_FORMAT }
  validate :timezone_is_iana
  validate :same_agency

  def self.normalize_code(value)
    value.to_s.strip.upcase
  end

  private

  def timezone_is_iana
    return if default_timezone.blank?

    TZInfo::Timezone.get(default_timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:default_timezone, "is not a recognized IANA timezone")
  end

  def same_agency
    return if agency_id.blank? || agency.blank?
    return if agency.id == agency_id

    errors.add(:agency, "must match the office tenant")
  end
end
