class Agency < ApplicationRecord
    has_many :agency_memberships, dependent: :restrict_with_exception
    has_many :users, through: :agency_memberships
    has_many :parties, dependent: :restrict_with_exception
    has_many :people, dependent: :restrict_with_exception
    has_many :households, dependent: :restrict_with_exception
    has_many :organizations, dependent: :restrict_with_exception
    has_many :offices, dependent: :restrict_with_exception
    has_many :office_assignments, dependent: :restrict_with_exception
    has_many :audit_events, dependent: :restrict_with_exception
    has_many :agency_provisioning_requests, dependent: :restrict_with_exception

    STATUSES = %w[
      active
      suspended
      closed
    ].freeze

    enum :status, STATUSES.index_by(&:itself)

    normalizes :name, with: ->(value) { value&.strip }
    normalizes :legal_name, with: ->(value) { value&.strip.presence }
    normalizes :country_code, with: ->(value) { value&.strip&.upcase }

    validates :name, presence: true
    validates :default_timezone, presence: true
    validates :default_currency,
      presence: true,
      format: {
        with: /\A[A-Z]{3}\z/,
        message: "must be a three-letter uppercase currency code"
      }
    validates :country_code,
      presence: true,
      format: {
        with: /\A[A-Z]{2}\z/,
        message: "must be a two-letter uppercase country code"
      }

    validate :default_timezone_must_be_valid

    def formal_name
      legal_name.presence || name
    end

    private

    def default_timezone_must_be_valid
      TZInfo::Timezone.get(default_timezone)
    rescue TZInfo::InvalidTimezoneIdentifier
      errors.add(
        :default_timezone,
        "is not a recognized IANA timezone"
      )
    end
end
