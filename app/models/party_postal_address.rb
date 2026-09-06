class PartyPostalAddress < ApplicationRecord
  self.primary_key = "contact_point_id"

  belongs_to :contact_point, class_name: "PartyContactPoint", inverse_of: :postal_address
  belongs_to :agency

  attribute :contact_kind, :string, default: "postal_address"
  attr_readonly :contact_kind, :agency_id, :contact_point_id

  normalizes :attention, :address_line_2, :address_line_3, :locality, :administrative_region, :postal_code,
    with: ->(value) { value&.strip.presence }
  normalizes :address_line_1, with: ->(value) { value&.strip }
  normalizes :country_code, with: ->(value) { value&.strip&.upcase }

  validates :address_line_1, :formatted_address, :normalized_address, presence: true
  validates :contact_kind, inclusion: { in: %w[postal_address] }
  validates :country_code, presence: true, format: { with: /\A[A-Z]{2}\z/, message: "must be a two-letter uppercase country code" }
  validate :country_code_known
  validate :agency_matches_contact_point

  before_validation :assign_formatted_values

  private

  def assign_formatted_values
    return if address_line_1.blank? || country_code.blank?

    self.formatted_address = PostalAddressFormatter.format(
      attention:,
      address_line_1:,
      address_line_2:,
      address_line_3:,
      locality:,
      administrative_region:,
      postal_code:,
      country_code:
    )
    self.normalized_address = PostalAddressFormatter.normalize(formatted_address)
    self.normalization_version ||= 1
  end

  def country_code_known
    return if country_code.blank? || CountryReference.valid_code?(country_code)

    errors.add(:country_code, "is not a recognized country")
  end

  def agency_matches_contact_point
    return if contact_point.blank? || agency_id.blank? || contact_point.agency_id == agency_id

    errors.add(:agency, "must match the contact point agency")
  end
end
