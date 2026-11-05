class Agency < ApplicationRecord
  STATUSES = %w[active suspended closed].freeze
  WORKSPACE_CODE_FORMAT = /\A[a-z][a-z0-9-]{1,39}\z/
  COUNTRY_CODE_FORMAT = /\A[A-Z]{2}\z/
  CURRENCY_FORMAT = /\A[A-Z]{3}\z/
  LOGO_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  LOGO_MAX_BYTES = 2.megabytes

  has_many :offices, dependent: :restrict_with_exception
  has_many :agency_users, dependent: :restrict_with_exception
  has_many :user_permissions, dependent: :restrict_with_exception
  has_many :resellers, dependent: :restrict_with_exception
  has_many :audit_events, dependent: :restrict_with_exception
  has_many :client_people, dependent: :restrict_with_exception
  has_many :client_organizations, dependent: :restrict_with_exception
  has_many :clients, dependent: :restrict_with_exception
  has_many :client_organization_contacts, dependent: :restrict_with_exception
  has_many :suppliers, dependent: :restrict_with_exception
  has_many :supplier_locations, class_name: "SupplierLocation", dependent: :restrict_with_exception
  has_many :supplier_contacts, class_name: "SupplierContact", dependent: :restrict_with_exception
  has_many :supplier_category_assignments, dependent: :restrict_with_exception
  has_many :supplier_email_addresses, dependent: :restrict_with_exception
  has_many :supplier_phone_numbers, dependent: :restrict_with_exception
  has_many :supplier_postal_addresses, dependent: :restrict_with_exception
  has_many :supplier_websites, dependent: :restrict_with_exception
  has_many :reference_sequences, dependent: :restrict_with_exception
  has_many :departures, dependent: :restrict_with_exception
  has_many :departure_team_members, dependent: :restrict_with_exception
  has_many :document_inclusions, class_name: "AgencyDocumentInclusion", dependent: :restrict_with_exception
  has_many :traveler_types, dependent: :restrict_with_exception

  # SET-08: optional, shown on documents (DOC-51). Served only through
  # AgencyLogosController (ADR 0019).
  has_one_attached :logo

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :workspace_code

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :legal_name, :agency_contact_name, with: ->(value) { value.to_s.strip.presence }
  normalizes :contact_email, with: ->(value) { value.to_s.strip.downcase.presence }
  normalizes :address_line_1, :address_line_2, :address_locality, :address_region, :address_postal_code,
    with: ->(value) { value.to_s.strip.presence }
  normalizes :address_country_code, with: ->(value) { value.to_s.strip.upcase.presence }
  normalizes :seller_of_travel_disclosure, :confirmation_footer, :financial_document_footer,
    with: ->(value) { value.to_s.gsub("\r\n", "\n").strip.presence }
  normalizes :workspace_code, with: ->(value) { normalize_workspace_code(value) }
  normalizes :country_code, with: ->(value) { value.to_s.strip.upcase }
  normalizes :default_currency, with: ->(value) { value.to_s.strip.upcase }
  normalizes :default_timezone, with: ->(value) { value.to_s.strip }

  validates :name, :workspace_code, :country_code, :default_currency, :default_timezone, presence: true
  validates :workspace_code, uniqueness: true, format: { with: WORKSPACE_CODE_FORMAT }
  validates :country_code, format: { with: COUNTRY_CODE_FORMAT }
  validates :default_currency, format: { with: CURRENCY_FORMAT }
  validates :contact_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :address_line_1, presence: true, if: :mailing_address_started?
  validates :address_country_code, presence: true, format: { with: COUNTRY_CODE_FORMAT }, if: :mailing_address_started?
  validates :hold_duration_days, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :installment_buffer_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :timezone_is_iana
  validate :logo_is_supported_image
  validate :currency_is_known

  def self.normalize_workspace_code(value)
    value.to_s.strip.downcase
  end

  def operational?
    active?
  end

  # SET-04: required to generate client documents, never to save the profile.
  def document_profile_blockers
    blockers = []
    blockers << "Enter the agency display name." if name.blank?
    blockers << "Enter the agency contact email." if contact_email.blank?
    blockers
  end

  def mailing_address_started?
    [ address_line_1, address_line_2, address_locality, address_region, address_postal_code, address_country_code ].any?(&:present?)
  end

  private

  def timezone_is_iana
    return if default_timezone.blank?

    TZInfo::Timezone.get(default_timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:default_timezone, "is not a recognized IANA timezone")
  end

  def logo_is_supported_image
    return unless logo.attached?

    errors.add(:logo, "must be a PNG, JPEG or WebP image") unless logo.blob.content_type.in?(LOGO_CONTENT_TYPES)
    errors.add(:logo, "must be 2 MB or smaller") if logo.blob.byte_size > LOGO_MAX_BYTES
  end

  def currency_is_known
    return if default_currency.blank?

    Money::Currency.find(default_currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:default_currency, "is not a supported currency")
  end
end
