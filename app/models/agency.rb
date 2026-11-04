class Agency < ApplicationRecord
  STATUSES = %w[active suspended closed].freeze
  WORKSPACE_CODE_FORMAT = /\A[a-z][a-z0-9-]{1,39}\z/
  COUNTRY_CODE_FORMAT = /\A[A-Z]{2}\z/
  CURRENCY_FORMAT = /\A[A-Z]{3}\z/

  has_many :offices, dependent: :restrict_with_exception
  has_many :agency_users, dependent: :restrict_with_exception
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

  enum :status, STATUSES.index_by(&:itself), validate: true

  attr_readonly :workspace_code

  normalizes :name, with: ->(value) { value.to_s.strip }
  normalizes :legal_name, with: ->(value) { value.to_s.strip.presence }
  normalizes :workspace_code, with: ->(value) { normalize_workspace_code(value) }
  normalizes :country_code, with: ->(value) { value.to_s.strip.upcase }
  normalizes :default_currency, with: ->(value) { value.to_s.strip.upcase }
  normalizes :default_timezone, with: ->(value) { value.to_s.strip }

  validates :name, :workspace_code, :country_code, :default_currency, :default_timezone, presence: true
  validates :workspace_code, uniqueness: true, format: { with: WORKSPACE_CODE_FORMAT }
  validates :country_code, format: { with: COUNTRY_CODE_FORMAT }
  validates :default_currency, format: { with: CURRENCY_FORMAT }
  validate :timezone_is_iana
  validate :currency_is_known

  def self.normalize_workspace_code(value)
    value.to_s.strip.downcase
  end

  def operational?
    active?
  end

  private

  def timezone_is_iana
    return if default_timezone.blank?

    TZInfo::Timezone.get(default_timezone)
  rescue TZInfo::InvalidTimezoneIdentifier
    errors.add(:default_timezone, "is not a recognized IANA timezone")
  end

  def currency_is_known
    return if default_currency.blank?

    Money::Currency.find(default_currency)
  rescue Money::Currency::UnknownCurrency
    errors.add(:default_currency, "is not a supported currency")
  end
end
