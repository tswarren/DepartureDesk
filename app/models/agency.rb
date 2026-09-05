class Agency < ApplicationRecord
    STATUSES = %w[
      active
      suspended
      closed
    ].freeze
  
    enum :status, STATUSES.index_by(&:itself)
  
    validates :name, presence: true
    validates :default_timezone, presence: true
    validates :default_currency,
      presence: true,
      format: {
        with: /\A[A-Z]{3}\z/,
        message: "must be a three-letter uppercase currency code"
      }
  
    validate :default_timezone_must_be_valid
  
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