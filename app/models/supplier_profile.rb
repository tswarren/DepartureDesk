class SupplierProfile < ApplicationRecord
  include RoleProfile

  PARTY_KINDS = %w[
    person
    organization
  ].freeze

  normalizes :default_currency, with: ->(value) { value&.strip&.upcase }

  validates :party_kind, inclusion: { in: PARTY_KINDS }
  validates :default_currency,
    presence: true,
    format: {
      with: /\A[A-Z]{3}\z/,
      message: "must be a three-letter uppercase currency code"
    }
end
