class Office < ApplicationRecord
  STATUSES = %w[active inactive].freeze
  CODE_FORMAT = /\A[A-Z][A-Z0-9]{1,9}\z/

  belongs_to :agency
  has_many :default_agency_users, class_name: "AgencyUser", foreign_key: :default_office_id, inverse_of: :default_office, dependent: :restrict_with_exception

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :agency_id, :code

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :code, with: ->(value) { normalize_code(value) }

  validates :name, :code, presence: true
  validates :code, uniqueness: { scope: :agency_id }, format: { with: CODE_FORMAT }
  validate :same_agency

  def self.normalize_code(value)
    value.to_s.strip.upcase
  end

  private

  def same_agency
    return if agency_id.blank? || agency.blank?
    return if agency.id == agency_id

    errors.add(:agency, "must match the office tenant")
  end
end
