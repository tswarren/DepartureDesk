class ClientPersonPostalAddress < ApplicationRecord
  include ClientPersonContactPoint

  normalizes :line_1, :line_2, :locality, :region, :postal_code, with: ->(value) { value.to_s.strip.presence }
  normalizes :country_code, with: ->(value) { value.to_s.strip.upcase.presence }

  validates :line_1, :country_code, presence: true
  validates :country_code, format: { with: CountryCode::SHAPE }
  validate :country_is_accepted

  private

  def country_is_accepted
    return if country_code.blank? || CountryCode.accepted?(country_code)

    errors.add(:country_code, "is not an accepted country")
  end
end
