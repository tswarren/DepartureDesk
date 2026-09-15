class SupplierContactPhoneNumber < ApplicationRecord
  include SupplierContactOwnedDestination

  normalizes :number, :normalized_number, :extension, :country_code,
    with: ->(value) { value.to_s.strip.presence }

  validates :number, :normalized_number, :country_code, presence: true
  validates :country_code, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true
  validate :accepted_country

  private

  def accepted_country
    return if country_code.blank? || CountryCode.accepted?(country_code)

    errors.add(:country_code, "is not an accepted country")
  end
end
