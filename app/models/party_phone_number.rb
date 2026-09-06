class PartyPhoneNumber < ApplicationRecord
  TYPES = %w[
    mobile
    home
    work
    main
    fax
    other
  ].freeze

  PARSE_STATUSES = %w[
    valid
    possible
    unparsed
  ].freeze

  self.primary_key = "contact_point_id"

  belongs_to :contact_point, class_name: "PartyContactPoint", inverse_of: :phone_number
  belongs_to :agency

  attribute :contact_kind, :string, default: "phone"
  attr_readonly :contact_kind, :agency_id, :contact_point_id

  enum :phone_type, TYPES.index_by(&:itself), validate: true
  enum :parse_status, PARSE_STATUSES.index_by(&:itself), validate: true, prefix: :parse

  normalizes :display_number, :normalized_digits, with: ->(value) { value&.strip }
  normalizes :extension, :e164_number, with: ->(value) { value&.strip.presence }
  normalizes :parsed_country_code, with: ->(value) { value&.strip&.upcase.presence }

  validates :display_number, :normalized_digits, presence: true
  validates :contact_kind, inclusion: { in: %w[phone] }
  validates :parsed_country_code,
    format: { with: /\A[A-Z]{2}\z/, message: "must be a two-letter uppercase country code" },
    allow_nil: true
  validate :agency_matches_contact_point

  private

  def agency_matches_contact_point
    return if contact_point.blank? || agency_id.blank? || contact_point.agency_id == agency_id

    errors.add(:agency, "must match the contact point agency")
  end
end
