class ClientPersonPhoneNumber < ApplicationRecord
  include ClientPersonContactPoint

  validates :number, :normalized_number, :country_code, presence: true
  validates :normalized_number, format: { with: PhoneNumberNormalizer::E164_SHAPE }
  validates :extension, format: { with: PhoneNumberNormalizer::EXTENSION_SHAPE }, allow_nil: true
  validates :country_code, format: { with: CountryCode::SHAPE }
  validate :country_is_accepted

  def formatted_number(viewer_country: nil)
    PhoneNumberNormalizer.display(
      normalized_number: normalized_number,
      country_code: country_code,
      extension: extension,
      viewer_country: viewer_country
    )
  end

  private

  def country_is_accepted
    return if country_code.blank? || CountryCode.accepted?(country_code)

    errors.add(:country_code, "is not an accepted country")
  end
end
